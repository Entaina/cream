class Company < ApplicationRecord
  include CrmRecord
  include HttpUrlFormat

  EMPLOYEE_RANGES = ["1-10", "11-50", "51-200", "201-500", "501-1000", "1000+"].freeze

  has_many :people, dependent: :destroy
  has_many :deals, dependent: :destroy

  validates :name, presence: true
  validates :employee_range, inclusion: {in: EMPLOYEE_RANGES}, allow_blank: true
  validates_http_url :linkedin_url, :twitter_url

  scope :search, ->(q) {
    where("companies.name ILIKE :q OR companies.domain ILIKE :q OR companies.industry ILIKE :q", q: "%#{sanitize_sql_like(q)}%") if q.present?
  }

  def display_name = name

  def initials
    name.split.first(2).map { |w| w[0] }.join.upcase
  end
end
