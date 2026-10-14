module Marketing
  # Registers a person as an MQL in one transaction (API and MCP entry point):
  # finds or creates the person by email, moves them to the "mql" lifecycle stage,
  # subscribes them to the given subscription types (which makes them eligible for the MQL
  # pool), and optionally stores internal notes, timeline notes, attachments and a product interest.
  # Consent is given per subscription type: at least one entry is required and each one must
  # carry its evidence (accepted text and where it was obtained), which is stored on that
  # subscription together with the user who registered it.
  #
  # Authorization is delegated to the caller through `authorizer`, a callable
  # that receives (record, query, **options) and raises when not allowed.
  class MqlCreator
    class Error < StandardError; end

    Result = Data.define(:person, :created, :subscriptions, :interest, :notes, :attachments, :email_message)
    Consent = Data.define(:subscription_type, :evidence)

    PERSON_FIELDS = %i[first_name last_name phone job_title location].freeze
    MQL_RANK = Person::LIFECYCLE_STAGES.index("mql")

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(workspace:, user:, attributes:, source:, authorizer:, subscriptions: [],
      product_id: nil, interest_description: nil, notes: [], attachments: [], email_data: nil)
      @workspace = workspace
      @user = user
      @attributes = attributes.to_h.symbolize_keys
      @source = source
      @authorizer = authorizer
      @subscription_entries = Array(subscriptions)
      @product_id = product_id.presence
      @interest_description = interest_description
      @notes = Array(notes)
      @attachments = Array(attachments)
      @email_data = email_data.presence
    end

    def call
      validate!

      email_message = nil
      email_creator = nil
      result = nil
      ActiveRecord::Base.transaction do
        person, created = save_person!
        advance_lifecycle!(person)
        subscriptions = subscribe!(person)
        interest = create_interest!(person)
        notes = create_notes!(person)
        attachments = create_attachments!(person)
        if @email_data
          email_creator = build_email_creator(person)
          email_message = email_creator.build
          authorizer.call(email_message, :create?)
          email_message.save!
        end
        Marketing::SegmentWatcher.sync_person!(person)
        result = Result.new(person:, created:, subscriptions:, interest:, notes:, attachments:, email_message:)
      end
      email_creator.deliver(email_message) if email_message
      result
    end

    private

    attr_reader :workspace, :user, :attributes, :source, :authorizer, :notes, :attachments

    def validate!
      raise Error, I18n.t("marketing.mql_creator.errors.email_required") if email.blank?

      consents # raises when the subscriptions or their consent evidence are invalid

      if attachments.any?
        unless CreamFeatures.enabled?(:attachments)
          raise Error, CreamFeatures.unavailable_message(:attachments)
        end
        Api::RecordAttachmentBuilder.ensure_count!(attachments)
      end

      if @email_data && !CreamFeatures.enabled?(:record_email)
        raise Error, CreamFeatures.unavailable_message(:record_email)
      end
    end

    def build_email_creator(person)
      Api::DealEmailCreator.new(
        workspace: workspace,
        user: user,
        record: person,
        email_attrs: @email_data[:attrs],
        attachments: @email_data[:attachments]
      )
    end

    # One entry per subscription type; the entry itself is the person's consent for that type.
    def consents
      @consents ||= begin
        raise Error, I18n.t("marketing.mql_creator.errors.subscriptions_required") if @subscription_entries.empty?

        built = @subscription_entries.map { |entry| build_consent(entry) }
        if built.map { |consent| consent.subscription_type.id }.uniq.size != built.size
          raise Error, I18n.t("marketing.mql_creator.errors.subscription_duplicated")
        end
        built
      end
    end

    def build_consent(entry)
      entry = entry.to_unsafe_h if entry.respond_to?(:to_unsafe_h)
      entry = entry.to_h.with_indifferent_access
      type = resolve_subscription_type!(entry[:subscription_type_id].to_s.strip.presence)

      Consent.new(subscription_type: type, evidence: ConsentEvidence.parse(entry))
    rescue ConsentEvidence::Error => e
      raise Error, e.message
    end

    def resolve_subscription_type!(id)
      raise Error, I18n.t("marketing.mql_creator.errors.subscription_type_required") if id.blank?

      workspace.subscription_types.active.find_by(id: id) ||
        raise(Error, I18n.t("marketing.mql_creator.errors.subscription_type_not_found", id: id))
    end

    def email
      @email ||= EmailAddressParser.extract(attributes[:email]) ||
        attributes[:email].to_s.strip.downcase.presence
    end

    def save_person!
      person = Person.find_by_email(workspace, email)
      return [update_person!(person), false] if person

      person = workspace.people.new(attributes.slice(*PERSON_FIELDS).merge(
        email: attributes[:email].presence,
        company: resolve_company!, owner: user, internal_notes: attributes[:internal_notes].presence
      ))
      authorizer.call(person, :create?)
      person.save!
      [person, true]
    end

    def update_person!(person)
      authorizer.call(person, :update?)
      PERSON_FIELDS.each do |field|
        person.public_send("#{field}=", attributes[field]) if person.public_send(field).blank? && attributes[field].present?
      end
      person.internal_notes = [person.internal_notes.presence, attributes[:internal_notes].presence].compact.join("\n\n").presence
      person.save! if person.changed?
      person
    end

    def resolve_company!
      if attributes[:company_id].present?
        workspace.companies.find(attributes[:company_id])
      elsif attributes[:company_name].present?
        name = attributes[:company_name].to_s.strip
        workspace.companies.where("LOWER(companies.name) = ?", name.downcase).first || create_company!(name)
      else
        raise Error, I18n.t("marketing.mql_creator.errors.company_required")
      end
    end

    def create_company!(name)
      company = workspace.companies.new(name: name, owner: user)
      authorizer.call(company, :create?)
      company.save!
      company
    end

    def advance_lifecycle!(person)
      previous = person.lifecycle_stage
      return if Person::LIFECYCLE_STAGES.index(previous).to_i >= MQL_RANK

      person.update!(lifecycle_stage: "mql")
      person.track_activity("lifecycle_changed", user: user, metadata: {"from" => previous, "to" => "mql"})
    end

    def subscribe!(person)
      consents.map do |consent|
        current = EmailSubscription.find_by(person: person, subscription_type: consent.subscription_type)
        # An active subscription keeps the evidence it was originally obtained with.
        next current if current&.subscribed?

        Marketing::ConsentService.subscribe!(
          person: person,
          subscription_type: consent.subscription_type,
          source: source,
          legal_basis: "consent",
          metadata: consent.evidence.metadata(user: user)
        )
      end
    end

    def create_interest!(person)
      return unless @product_id

      interest = person.product_interests.build(
        workspace: workspace,
        product: workspace.products.find(@product_id),
        description: @interest_description,
        recorded_by: user,
        source_kind: "manual",
        occurred_at: Time.current,
        status: "pending"
      )
      authorizer.call(interest, :create?, policy_class: Marketing::ProductInterestPolicy)
      interest.save!
      interest
    end

    def create_notes!(person)
      notes.filter_map do |entry|
        entry = entry.to_unsafe_h if entry.respond_to?(:to_unsafe_h)
        next unless entry.is_a?(Hash)

        entry = entry.with_indifferent_access
        note = person.notes.new(workspace: workspace, user: user, title: entry[:title], body: entry[:body])
        authorizer.call(note, :create?)
        note.save!
        note
      end
    end

    def create_attachments!(person)
      return [] if attachments.empty?

      builder = Api::RecordAttachmentBuilder.new(workspace: workspace, user: user, record: person)
      attachments.map do |raw|
        attachment = builder.build(raw)
        authorizer.call(attachment, :create?)
        attachment.save!
        attachment
      end
    end
  end
end
