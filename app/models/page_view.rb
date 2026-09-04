class PageView < ApplicationRecord
  belongs_to :workspace
  belongs_to :person, optional: true

  validates :anonymous_id, :url, :occurred_at, presence: true

  scope :recent_first, -> { order(occurred_at: :desc, id: :desc) }

  def self.record!(workspace:, anonymous_id:, url:, referrer: nil, utm: {}, session_id: nil, person: nil, metadata: {})
    create!(
      workspace: workspace,
      person: person,
      anonymous_id: anonymous_id,
      url: url,
      referrer: referrer,
      utm_source: utm["utm_source"],
      utm_medium: utm["utm_medium"],
      utm_campaign: utm["utm_campaign"],
      utm_term: utm["utm_term"],
      utm_content: utm["utm_content"],
      session_id: session_id,
      occurred_at: Time.current,
      metadata: metadata
    )
  end
end
