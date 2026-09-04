class SubscriptionType < ApplicationRecord
  belongs_to :workspace
  has_many :email_subscriptions, dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :workspace_id }, format: { with: /\A[a-z0-9_-]+\z/ }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name, :id) }

  before_validation :normalize_slug

  def self.ensure_defaults!(workspace)
    [
      { name: "General", slug: "general", description: "Comunicaciones generales del workspace" },
      { name: "Newsletter", slug: "newsletter", description: "Boletín y novedades" },
      { name: "Producto", slug: "product", description: "Comunicaciones sobre productos y servicios" },
      { name: "Eventos", slug: "events", description: "Invitaciones y recordatorios de eventos" }
    ].each_with_index do |attrs, index|
      workspace.subscription_types.find_or_create_by!(slug: attrs[:slug]) do |type|
        type.name = attrs[:name]
        type.description = attrs[:description]
        type.position = index
      end
    end
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize(separator: "_") if slug.present?
  end
end
