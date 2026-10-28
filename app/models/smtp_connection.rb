class SmtpConnection < ApplicationRecord
  AUTHENTICATIONS = %w[plain login cram_md5].freeze

  belongs_to :workspace
  belongs_to :user

  encrypts :password

  validates :workspace_id, uniqueness: true
  validates :address, :from_email, presence: true
  validates :from_email, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :port, numericality: {only_integer: true, in: 1..65_535}
  validates :authentication, inclusion: {in: AUTHENTICATIONS}
  validates :password, presence: true, if: -> { user_name.present? }

  def connected? = address.present? && from_email.present?

  def masked_password
    mask(password)
  end

  def delivery_settings
    settings = {
      address: address,
      port: port,
      domain: domain.presence || from_email.to_s.split("@").last.presence || "localhost",
      enable_starttls_auto: enable_starttls_auto?
    }
    if user_name.present?
      settings[:user_name] = user_name
      settings[:password] = password
      settings[:authentication] = authentication.to_sym
    end
    settings
  end

  private

  def mask(value)
    return "" if value.blank?
    return "…" if value.length < 8

    "#{value.first(4)}…#{value.last(4)}"
  end
end
