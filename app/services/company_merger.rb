# Merges duplicate Company records within a workspace into a single survivor.
class CompanyMerger
  class Error < StandardError; end

  SCALAR_FIELDS = %i[
    domain description industry employee_range location linkedin_url twitter_url
    annual_revenue fiscal_information owner_id
  ].freeze

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(primary:, secondaries:, user: Current.user)
    @primary = primary
    @secondaries = Array(secondaries)
    @user = user
  end

  def call
    validate!

    ActiveRecord::Base.transaction do
      merge_scalar_fields!
      reassign_people!
      reassign_deals!
      reassign_polymorphic_records!
      merge_list_entries!
      merge_custom_field_values!
      update_record_references!
      primary.save! if primary.changed?
      track_merge!
      secondaries.each do |secondary|
        secondary.reload
        secondary.destroy!
      end
      primary.reload
    end
  end

  private

  attr_reader :primary, :secondaries, :user

  def validate!
    raise Error, I18n.t("companies.merge.errors.no_secondaries") if secondaries.empty?
    raise Error, I18n.t("companies.merge.errors.same_primary") if secondaries.include?(primary)

    ([primary] + secondaries).each do |company|
      raise Error, I18n.t("companies.merge.errors.same_workspace") if company.workspace_id != primary.workspace_id
    end
  end

  def merge_scalar_fields!
    secondaries.each do |secondary|
      SCALAR_FIELDS.each do |field|
        next if primary.public_send(field).present?

        value = secondary.public_send(field)
        primary.public_send("#{field}=", value) if value.present?
      end
    end
  end

  def reassign_people!
    secondaries.each do |secondary|
      secondary.people.order(:created_at, :id).find_each do |person|
        existing = find_matching_person(person)
        person.update_columns(company_id: primary.id, updated_at: Time.current)

        if existing
          PersonMerger.call(primary: existing, secondaries: [person], user: user)
        end
      end
    end
  end

  def find_matching_person(person)
    emails = person.person_emails.pluck(:address)
    emails << person.email if person.email.present?
    emails.map! { |address| address.to_s.strip.downcase }.uniq!
    emails.filter_map { |email| find_person_by_email(email) }.first
  end

  def find_person_by_email(email)
    return if email.blank?

    normalized = email.to_s.strip.downcase
    primary.people.with_email(normalized).first
  end

  def reassign_deals!
    Deal.where(company_id: secondaries.map(&:id)).update_all(company_id: primary.id, updated_at: Time.current)
  end

  def reassign_polymorphic_records!
    secondary_ids = secondaries.map(&:id)

    Note.where(notable_type: "Company", notable_id: secondary_ids).update_all(notable_id: primary.id)
    Comment.where(commentable_type: "Company", commentable_id: secondary_ids).update_all(commentable_id: primary.id)
    Task.where(taskable_type: "Company", taskable_id: secondary_ids).update_all(taskable_id: primary.id)
    Activity.where(subject_type: "Company", subject_id: secondary_ids).update_all(subject_id: primary.id)
    RecordAttachment.where(attachable_type: "Company", attachable_id: secondary_ids).update_all(attachable_id: primary.id)
    EmailMessage.where(record_type: "Company", record_id: secondary_ids).update_all(record_id: primary.id)
  end

  def merge_list_entries!
    secondaries.each do |secondary|
      ListEntry.where(record_type: "Company", record_id: secondary.id).find_each do |entry|
        if ListEntry.exists?(list_id: entry.list_id, record_type: "Company", record_id: primary.id)
          entry.delete
        else
          entry.update_columns(record_id: primary.id, updated_at: Time.current)
        end
      end
    end
  end

  def merge_custom_field_values!
    secondaries.each do |secondary|
      secondary.custom_field_values.find_each do |cfv|
        primary_cfv = CustomFieldValue.find_by(
          custom_field_id: cfv.custom_field_id,
          record_type: "Company",
          record_id: primary.id
        )

        if primary_cfv
          if primary_cfv.blank_value? && !cfv.blank_value?
            primary_cfv.update!(value: cfv.value)
          end
          cfv.destroy!
        else
          cfv.update_columns(record_id: primary.id, updated_at: Time.current)
        end
      end
    end
  end

  def update_record_references!
    field_ids = primary.workspace.custom_fields
      .where(field_type: "record_reference", reference_type: "Company")
      .pluck(:id)
    return if field_ids.empty?

    secondaries.each do |secondary|
      CustomFieldValue.where(custom_field_id: field_ids)
        .where("value = ?::jsonb", secondary.id.to_json)
        .update_all(value: primary.id, updated_at: Time.current)
    end
  end

  def track_merge!
    primary.track_activity("merged", user: user, metadata: {
      merged_companies: secondaries.map { |company|
        {"id" => company.id, "name" => company.display_name, "domain" => company.domain}
      }
    })
  end
end
