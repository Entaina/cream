require "open3"

# Dumps the primary PostgreSQL database, uploads the file to Google Drive, and
# deletes backups older than 30 days except those created on the 1st of each month.
class DatabaseBackupService
  Error = Class.new(StandardError)
  Result = Data.define(:uploaded_file_name, :deleted_files)

  def initialize(storage: nil, db_config: ActiveRecord::Base.connection_db_config, environment: Rails.env)
    @environment = environment.to_s
    @storage = storage || GoogleDriveBackupStorage.new(environment: @environment)
    @db_config = db_config
  end

  def call
    backup_date = Date.current
    file_name = backup_filename(backup_date)

    Tempfile.create([ "cream_backup_#{@environment}_", ".dump" ]) do |tempfile|
      run_pg_dump(tempfile.path)
      @storage.upload(tempfile.path, name: file_name)
    end

    deleted_files = apply_retention_policy

    Result.new(uploaded_file_name: file_name, deleted_files: deleted_files)
  end

  private

  def backup_filename(date)
    GoogleDriveBackupStorage.backup_filename(@environment, date)
  end

  def run_pg_dump(output_path)
    configuration = @db_config.configuration_hash
    env = { "PGPASSWORD" => configuration[:password].to_s }
    command = [
      "pg_dump",
      "-Fc",
      "-h", configuration[:host].to_s,
      "-p", configuration[:port].to_s,
      "-U", configuration[:username].to_s,
      "-d", configuration[:database].to_s,
      "-f", output_path
    ]

    _stdout, stderr, status = Open3.capture3(env, *command)
    return if status.success?

    raise Error, "pg_dump failed (#{status.exitstatus}): #{stderr.presence || "unknown error"}"
  end

  def apply_retention_policy
    cutoff = 30.days.ago.to_date
    deleted_files = []

    @storage.list_backups.each do |backup|
      backup_date = backup_date_for(backup)
      next unless backup_date
      next unless backup_date < cutoff
      next if backup_date.day == 1

      @storage.delete(backup.id)
      deleted_files << backup.name
    end

    deleted_files
  end

  def backup_date_for(backup)
    match = backup.name.match(GoogleDriveBackupStorage.backup_name_pattern(@environment))
    return Date.iso8601(match[1]) if match

    backup.created_time&.to_date
  end
end
