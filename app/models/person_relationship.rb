# Directed link between two people in the same workspace (e.g. A invited B).
class PersonRelationship < ApplicationRecord
  TYPES = {
    "invited" => {symmetric: false},
    "referred_by" => {symmetric: false},
    "worked_with" => {symmetric: true},
    "colleague_of" => {symmetric: true}
  }.freeze

  SYMMETRIC_TYPES = TYPES.select { |_, config| config[:symmetric] }.keys.freeze

  belongs_to :from_person, class_name: "Person", inverse_of: :outgoing_relationships
  belongs_to :to_person, class_name: "Person", inverse_of: :incoming_relationships

  validates :relationship_type, inclusion: {in: TYPES.keys}
  validates :to_person_id, uniqueness: {scope: [:from_person_id, :relationship_type]}
  validate :no_self_link
  validate :same_workspace
  validate :no_duplicate_symmetric_pair

  def self.type_options_for_select
    TYPES.keys.map { |key| [I18n.t("people.relationships.types.#{key}.from").capitalize, key] }
  end

  def label_for(viewer)
    side = if viewer.id == from_person_id
      "from"
    elsif viewer.id == to_person_id
      "to"
    else
      raise ArgumentError, "viewer is not part of this relationship"
    end

    I18n.t("people.relationships.types.#{relationship_type}.#{side}")
  end

  def other_person(viewer)
    (viewer.id == from_person_id) ? to_person : from_person
  end

  def involves?(person)
    [from_person_id, to_person_id].include?(person.id)
  end

  private

  def no_self_link
    return if from_person_id.blank? || to_person_id.blank?
    return unless from_person_id == to_person_id

    errors.add(:to_person, :cannot_be_same_person)
  end

  def same_workspace
    return if from_person.blank? || to_person.blank?
    return if from_person.workspace_id == to_person.workspace_id

    errors.add(:to_person, :must_belong_to_same_workspace)
  end

  def no_duplicate_symmetric_pair
    return unless SYMMETRIC_TYPES.include?(relationship_type)
    return if from_person_id.blank? || to_person_id.blank?

    duplicate = self.class.where(
      from_person_id: to_person_id,
      to_person_id: from_person_id,
      relationship_type: relationship_type
    )
    duplicate = duplicate.where.not(id: id) if persisted?
    return unless duplicate.exists?

    errors.add(:base, :relationship_exists_opposite)
  end
end
