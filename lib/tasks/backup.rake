namespace :cream do
  namespace :backup do
    desc "Dump the primary database and upload it to Google Drive"
    task run: :environment do
      key_path = ENV["GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH"]
      unless key_path.present? && File.file?(key_path) &&
             ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"].present?
        abort "Google Drive backup is not configured (GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH must point to an existing file and GOOGLE_DRIVE_BACKUP_FOLDER_ID is required)."
      end

      result = DatabaseBackupService.new.call

      puts "Uploaded: #{result.uploaded_file_name}"
      if result.deleted_files.any?
        puts "Deleted #{result.deleted_files.size} old backup(s):"
        result.deleted_files.each { |name| puts "  - #{name}" }
      else
        puts "No old backups deleted."
      end
    end

    desc "Restore a database backup from Google Drive (latest for this env, or a specific file name)"
    task :restore, [ :file_name ] => :environment do |_task, args|
      key_path = ENV["GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH"]
      unless key_path.present? && File.file?(key_path) &&
             ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"].present?
        abort "Google Drive backup is not configured (GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH must point to an existing file and GOOGLE_DRIVE_BACKUP_FOLDER_ID is required)."
      end

      if Rails.env.production? && ENV["CONFIRM"] != "1"
        abort "Restoring in production overwrites the database. Set CONFIRM=1 to proceed."
      end

      result = DatabaseRestoreService.new.call(file_name: args[:file_name].presence)

      puts "Restored: #{result.restored_file_name}"
    end
  end
end
