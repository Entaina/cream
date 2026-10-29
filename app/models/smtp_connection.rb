class SmtpConnection < ApplicationRecord
  AUTHENTICATIONS = %w[plain login cram_md5].freeze
  PORTS = [25, 465, 587, 2525].freeze
  UnsafeAddressError = Class.new(StandardError)

  belongs_to :workspace
  belongs_to :user

  encrypts :password

  validates :workspace_id, uniqueness: true
  validates :address, :from_email, presence: true
  validates :from_email, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :port, inclusion: {in: PORTS}
  validates :authentication, inclusion: {in: AUTHENTICATIONS}
  validates :password, presence: true, if: -> { user_name.present? }
  validate :address_must_be_public, if: -> { address.present? && will_save_change_to_address? }

  def connected? = address.present? && from_email.present?

  def masked_password
    mask(password)
  end

  # Checks the host again right before delivery, since its DNS may have changed
  # since it was saved. The connection still goes to the host name: mail does not
  # pass tls_hostname to Net::SMTP, so connecting to the IP would fail TLS checks.
  def delivery_settings
    begin
      SafeOutboundHttp.resolve_public_host!(address)
    rescue ArgumentError => e
      raise UnsafeAddressError, "SMTP host #{address} rejected: #{e.message}"
    end

    settings = {
      address: address,
      port: port,
      domain: domain.presence || from_email.to_s.split("@").last.presence || "localhost",
      enable_starttls_auto: enable_starttls_auto?,
      open_timeout: 5,
      read_timeout: 10
    }
    if user_name.present?
      settings[:user_name] = user_name
      settings[:password] = password
      settings[:authentication] = authentication.to_sym
    end
    settings
  end

  private

  def address_must_be_public
    SafeOutboundHttp.resolve_public_host!(address)
  rescue ArgumentError
    errors.add(:address, :must_be_public_host)
  end

  def mask(value)
    return "" if value.blank?
    return "…" if value.length < 8

    "#{value.first(4)}…#{value.last(4)}"
  end
end
