require "fileutils"
require "open3"
require "tempfile"

# Optional age encryption for pg_dump backups (public key encrypts, identity decrypts).
module DatabaseBackupAge
  Error = Class.new(StandardError)

  module_function

  def encrypted_name?(file_name)
    file_name.to_s.end_with?(".age")
  end

  def encrypt_if_configured(source_path, file_name)
    recipient = ENV["BACKUP_AGE_PUBLIC_KEY"].to_s.strip
    return [source_path, file_name] if recipient.blank?

    encrypted_path = "#{source_path}.age"
    _stdout, stderr, status = Open3.capture3("age", "-r", recipient, "-o", encrypted_path, source_path)
    unless status.success?
      FileUtils.rm_f(encrypted_path)
      raise Error, "age encryption failed: #{stderr.presence || "unknown error"}"
    end

    [encrypted_path, "#{file_name}.age"]
  end

  def decrypt_if_needed(source_path, backup_name)
    return source_path unless encrypted_name?(backup_name)

    identity = age_identity_file
    decrypted_path = "#{source_path}.decrypted.dump"
    begin
      _stdout, stderr, status = Open3.capture3(
        "age", "-d", "-i", identity.path, "-o", decrypted_path, source_path
      )
      unless status.success?
        FileUtils.rm_f(decrypted_path)
        raise Error, "age decryption failed: #{stderr.presence || "unknown error"}"
      end

      decrypted_path
    ensure
      identity.close
    end
  end

  def age_identity_file
    path = ENV["BACKUP_AGE_IDENTITY_FILE"].to_s.strip
    if path.present?
      raise Error, "BACKUP_AGE_IDENTITY_FILE not found: #{path}" unless File.file?(path)

      return IdentityFile.new(path:, tempfile: nil)
    end

    key = ENV["BACKUP_AGE_IDENTITY"].to_s.strip
    raise Error, "Backup is age-encrypted but BACKUP_AGE_IDENTITY_FILE or BACKUP_AGE_IDENTITY is not configured" if key.blank?

    file = Tempfile.new(["cream_backup_age_identity", ".txt"])
    file.write(key)
    file.flush
    IdentityFile.new(path: file.path, tempfile: file)
  end

  IdentityFile = Data.define(:path, :tempfile) do
    def close
      tempfile&.close!
    end
  end
end
