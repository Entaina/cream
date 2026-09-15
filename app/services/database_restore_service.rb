require "open3"

# Downloads a database backup from Google Drive and restores it with pg_restore.
class DatabaseRestoreService
  Error = Class.new(StandardError)
  Result = Data.define(:restored_file_name)

  def initialize(storage: nil, db_config: ActiveRecord::Base.connection_db_config, environment: Rails.env)
    @environment = environment.to_s
    @storage = storage || GoogleDriveBackupStorage.new(environment: @environment)
    @db_config = db_config
  end

  def call(file_name: nil)
    backup = file_name.present? ? find_by_name!(file_name) : latest_backup!

    Tempfile.create(["cream_restore_", ".dump"]) do |tempfile|
      @storage.download(backup.id, tempfile.path)
      run_pg_restore(tempfile.path)
    end

    Result.new(restored_file_name: backup.name)
  end

  private

  def find_by_name!(file_name)
    @storage.find_by_name(file_name) || raise(Error, "Backup not found in Drive: #{file_name}")
  end

  def latest_backup!
    backups = @storage.list_backups
    raise Error, "No backups found for environment: #{@environment}" if backups.empty?

    backups.max_by { |backup| backup_date_for(backup) || Date.new(1900, 1, 1) }
  end

  def backup_date_for(backup)
    match = backup.name.match(GoogleDriveBackupStorage.backup_name_pattern(@environment))
    return Date.iso8601(match[1]) if match

    backup.created_time&.to_date
  end

  def run_pg_restore(input_path)
    configuration = @db_config.configuration_hash
    env = {"PGPASSWORD" => configuration[:password].to_s}
    command = [
      "pg_restore",
      "--clean",
      "--if-exists",
      "--no-owner",
      "--no-privileges",
      "-h", configuration[:host].to_s,
      "-p", configuration[:port].to_s,
      "-U", configuration[:username].to_s,
      "-d", configuration[:database].to_s,
      input_path
    ]

    _stdout, stderr, status = Open3.capture3(env, *command)
    return if status.success?

    raise Error, "pg_restore failed (#{status.exitstatus}): #{stderr.presence || "unknown error"}"
  end
end
