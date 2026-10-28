Rails.application.configure do
  if Rails.env.test?
    config.active_record.encryption.primary_key = "test_primary_key_32_characters!!"
    config.active_record.encryption.deterministic_key = "test_deterministic_key_32_chars!!"
    config.active_record.encryption.key_derivation_salt = "test_key_derivation_salt_32_chars!"
  else
    keys = {
      primary_key: "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY",
      deterministic_key: "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY",
      key_derivation_salt: "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"
    }.to_h do |name, env_var|
      [name, ENV[env_var].presence || Rails.application.credentials.dig(:active_record_encryption, name)]
    end

    if Rails.env.development?
      keys[:primary_key] ||= "development_primary_key_32_chars!"
      keys[:deterministic_key] ||= "development_deterministic_key_32!"
      keys[:key_derivation_salt] ||= "development_key_derivation_salt!!"
    end

    missing = keys.select { |_name, value| value.blank? }.keys
    if missing.any? && Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
      raise "Missing Active Record encryption keys (#{missing.join(", ")}). " \
        "Generate them with `bin/rails db:encryption:init` and set ACTIVE_RECORD_ENCRYPTION_* in .env " \
        "(see deploy/ENCRYPTION_ROTATION.md)."
    end

    keys.each { |name, value| config.active_record.encryption.public_send(:"#{name}=", value) }
  end
  config.active_record.encryption.support_unencrypted_data = true
end
