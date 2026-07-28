class ListFilterState < ApplicationRecord
  belongs_to :session
  belongs_to :workspace

  validates :key, presence: true

  class << self
    def read(session:, workspace:, key:)
      return nil if session.blank? || workspace.blank? || key.blank?

      rec = find_by(session: session, workspace: workspace, key: key)
      return nil if rec.nil?

      rec.params.deep_stringify_keys
    end

    def write(session:, workspace:, key:, params:)
      return if session.blank? || workspace.blank? || key.blank?

      h =
        case params
        when ActionController::Parameters
          params.to_unsafe_h
        when Hash
          params
        else
          params.to_h
        end

      rec = find_or_initialize_by(session: session, workspace: workspace, key: key)
      rec.params = h.deep_stringify_keys
      rec.save!
    end

    def delete(session:, workspace:, key:)
      return if session.blank? || workspace.blank? || key.blank?

      where(session: session, workspace: workspace, key: key).delete_all
    end
  end
end
