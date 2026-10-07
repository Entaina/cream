# Merges duplicate Person records within a workspace into a single survivor.
class PersonMerger
  class Error < StandardError; end

  SCALAR_FIELDS = %i[
    phone job_title location linkedin_url twitter_url description
    source owner_id brought_by_id
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
      merge_internal_notes!
      merge_person_emails!
      reassign_polymorphic_records!
      merge_deal_contacts!
      merge_person_relationships!
      merge_list_entries!
      merge_product_interests!
      merge_lead_submissions!
      merge_bookings!
      merge_custom_field_values!
      update_record_references!
      reassign_stripe_payments!
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
    raise Error, I18n.t("people.merge.errors.no_secondaries") if secondaries.empty?
    raise Error, I18n.t("people.merge.errors.same_primary") if secondaries.include?(primary)

    ([primary] + secondaries).each do |person|
      raise Error, I18n.t("people.merge.errors.same_workspace") if person.workspace_id != primary.workspace_id
    end
  end

  def merge_scalar_fields!
    secondaries.each do |secondary|
      SCALAR_FIELDS.each do |field|
        next if primary.public_send(field).present?

        value = secondary.public_send(field)
        next if field == :source && value == "team_member" && secondary.brought_by_id.blank?

        primary.public_send("#{field}=", value) if value.present?
      end
    end

    dates = ([primary.first_contact_on] + secondaries.map(&:first_contact_on)).compact
    primary.first_contact_on = dates.min if dates.any?
  end

  # Free-text notes are never discarded: the secondaries' notes are appended to the primary's.
  def merge_internal_notes!
    secondary_notes = secondaries.map { |secondary| secondary.internal_notes.to_s.strip }.reject(&:blank?)
    return if secondary_notes.empty?

    combined = ([primary.internal_notes.to_s.strip] + secondary_notes).reject(&:blank?).uniq
    primary.internal_notes = combined.join("\n\n")
  end

  def merge_person_emails!
    secondaries.each do |secondary|
      secondary_email_addresses(secondary).each do |address|
        next if primary.person_emails.exists?(["LOWER(TRIM(address)) = ?", address])

        primary.add_email!(address, primary: false)
      end

      secondary.person_emails.reload.destroy_all
    end
    primary.refresh_primary_email_column!
  end

  def secondary_email_addresses(secondary)
    addresses = secondary.person_emails.pluck(:address).map { |address| address.downcase.strip }
    legacy = secondary.email.to_s.strip.downcase.presence
    addresses << legacy if legacy.present?
    addresses.uniq
  end

  def reassign_polymorphic_records!
    secondary_ids = secondaries.map(&:id)

    Note.where(notable_type: "Person", notable_id: secondary_ids).update_all(notable_id: primary.id)
    Comment.where(commentable_type: "Person", commentable_id: secondary_ids).update_all(commentable_id: primary.id)
    Task.where(taskable_type: "Person", taskable_id: secondary_ids).update_all(taskable_id: primary.id)
    Activity.where(subject_type: "Person", subject_id: secondary_ids).update_all(subject_id: primary.id)
    RecordAttachment.where(attachable_type: "Person", attachable_id: secondary_ids).update_all(attachable_id: primary.id)
    EmailMessage.where(record_type: "Person", record_id: secondary_ids).update_all(record_id: primary.id)
  end

  def merge_deal_contacts!
    secondaries.each do |secondary|
      DealContact.where(person_id: secondary.id).find_each do |deal_contact|
        if DealContact.exists?(deal_id: deal_contact.deal_id, person_id: primary.id)
          deal_contact.delete
        else
          deal_contact.update_columns(person_id: primary.id, updated_at: Time.current)
        end
      end
    end
  end

  def merge_person_relationships!
    secondary_ids = secondaries.map(&:id)

    PersonRelationship.where(from_person_id: secondary_ids).or(
      PersonRelationship.where(to_person_id: secondary_ids)
    ).find_each do |relationship|
      new_from = secondary_ids.include?(relationship.from_person_id) ? primary.id : relationship.from_person_id
      new_to = secondary_ids.include?(relationship.to_person_id) ? primary.id : relationship.to_person_id

      if new_from == new_to
        relationship.delete
        next
      end

      if PersonRelationship.exists?(
        from_person_id: new_from,
        to_person_id: new_to,
        relationship_type: relationship.relationship_type
      )
        relationship.delete
      else
        relationship.update_columns(
          from_person_id: new_from,
          to_person_id: new_to,
          updated_at: Time.current
        )
      end
    end
  end

  def merge_product_interests!
    Marketing::ProductInterest.where(person_id: secondaries.map(&:id))
      .update_all(person_id: primary.id, updated_at: Time.current)
  end

  def merge_lead_submissions!
    LeadSubmission.where(person_id: secondaries.map(&:id))
      .update_all(person_id: primary.id, updated_at: Time.current)
  end

  def merge_bookings!
    Booking.where(person_id: secondaries.map(&:id))
      .update_all(person_id: primary.id, updated_at: Time.current)
  end

  def merge_list_entries!
    secondaries.each do |secondary|
      ListEntry.where(record_type: "Person", record_id: secondary.id).find_each do |entry|
        if ListEntry.exists?(list_id: entry.list_id, record_type: "Person", record_id: primary.id)
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
          record_type: "Person",
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
      .where(field_type: "record_reference", reference_type: "Person")
      .pluck(:id)
    return if field_ids.empty?

    secondaries.each do |secondary|
      CustomFieldValue.where(custom_field_id: field_ids)
        .where("value = ?::jsonb", secondary.id.to_json)
        .update_all(value: primary.id, updated_at: Time.current)
    end
  end

  def reassign_stripe_payments!
    StripePayment.where(suggested_person_id: secondaries.map(&:id))
      .update_all(suggested_person_id: primary.id, updated_at: Time.current)
  end

  def track_merge!
    primary.track_activity("merged", user: user, metadata: {
      merged_people: secondaries.map { |person|
        {"id" => person.id, "name" => person.display_name, "email" => person.email}
      }
    })
  end
end
