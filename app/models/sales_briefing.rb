class SalesBriefing < ApplicationRecord
  RECORD_TYPES = %w[Deal Person Company Task].freeze
  PRIORITIES = %w[urgent important].freeze

  belongs_to :workspace
  belongs_to :user, optional: true

  validates :briefing_date, presence: true
  validates :generated_at, presence: true
  validate :unique_briefing_date
  validate :items_structure
  validate :personal_fields_structure

  scope :latest, -> { order(briefing_date: :desc, id: :desc) }
  scope :team, -> { where(user_id: nil) }
  scope :personal, -> { where.not(user_id: nil) }
  scope :personal_for, ->(user) { personal.where(user: user) }

  def team?
    user_id.nil?
  end

  def personal?
    !team?
  end

  def urgent_items
    items_for("urgent")
  end

  def important_items
    items_for("important")
  end

  def record_for(item)
    type = item["record_type"].to_s
    id = item["record_id"]
    return nil unless type.in?(RECORD_TYPES) && id.present?

    case type
    when "Deal" then workspace.deals.find_by(id: id)
    when "Person" then workspace.people.find_by(id: id)
    when "Company" then workspace.companies.find_by(id: id)
    when "Task" then workspace.tasks.find_by(id: id)
    end
  end

  def owner_for(item)
    owner_id = item["owner_id"]
    return nil if owner_id.blank?

    workspace.users.find_by(id: owner_id)
  end

  private

  def items_for(priority)
    Array(items).select { |item| item.is_a?(Hash) && item["priority"].to_s == priority }
  end

  def unique_briefing_date
    scope = self.class.where(workspace_id: workspace_id, briefing_date: briefing_date)
    scope = user_id.present? ? scope.where(user_id: user_id) : scope.where(user_id: nil)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:briefing_date, :taken) if scope.exists?
  end

  def items_structure
    return if items.blank?

    Array(items).each do |item|
      unless item.is_a?(Hash)
        errors.add(:items, "must be an array of objects")
        break
      end

      priority = item["priority"].to_s
      unless PRIORITIES.include?(priority)
        errors.add(:items, "contains an invalid priority")
        break
      end

      if item["text"].blank?
        errors.add(:items, "each item must include text")
        break
      end
    end
  end

  def personal_fields_structure
    validate_string_array(:wins)
    validate_string_array(:misses)
    return unless team?

    errors.add(:wins, "must be empty for team briefings") if Array(wins).any?
    errors.add(:misses, "must be empty for team briefings") if Array(misses).any?
  end

  def validate_string_array(attribute)
    value = public_send(attribute)
    return if value.blank?

    unless value.is_a?(Array) && value.all? { |entry| entry.is_a?(String) && entry.present? }
      errors.add(attribute, "must be an array of strings")
    end
  end
end
