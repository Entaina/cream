class DatabaseBackupJob < ApplicationJob
  queue_as :default

  # Runs daily in production only (see config/recurring.yml).
  def perform
    unless Rails.env.production?
      Rails.logger.info("[DatabaseBackupJob] skipped: not running in #{Rails.env}")
      return
    end

    unless configured?
      Rails.logger.warn("[DatabaseBackupJob] skipped: Google Drive backup is not configured")
      return
    end

    result = DatabaseBackupService.new.call
    Rails.logger.info(
      "[DatabaseBackupJob] uploaded #{result.uploaded_file_name}, deleted #{result.deleted_files.size} old backup(s)"
    )
  end

  private

  def configured?
    key_path = ENV["GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH"]
    key_path.present? &&
      File.file?(key_path) &&
      ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"].present?
  end
end
