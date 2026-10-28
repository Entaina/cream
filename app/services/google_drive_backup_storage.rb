require "google/apis/drive_v3"
require "googleauth"

# Uploads database backup files to a Google Drive folder in a Shared Drive using
# a service account. All API calls use supports_all_drives so Shared Drive access works.
class GoogleDriveBackupStorage
  Error = Class.new(StandardError)
  BackupFile = Data.define(:id, :name, :created_time)

  DRIVE_SCOPE = Google::Apis::DriveV3::AUTH_DRIVE_FILE

  def self.backup_filename(environment, date)
    "cream_backup_#{environment}_#{date.iso8601}.dump"
  end

  def self.backup_name_pattern(environment = Rails.env)
    /\Acream_backup_#{Regexp.escape(environment.to_s)}_(\d{4}-\d{2}-\d{2})\.dump(\.age)?\z/
  end

  def initialize(drive_service: nil, environment: Rails.env)
    @environment = environment.to_s
    @drive_service = drive_service || build_drive_service
  end

  def upload(path, name:)
    metadata = Google::Apis::DriveV3::File.new(name: name, parents: [folder_id])
    @drive_service.create_file(
      metadata,
      supports_all_drives: true,
      upload_source: path,
      content_type: "application/octet-stream"
    )
  end

  def list_backups
    response = @drive_service.list_files(
      q: "'#{folder_id}' in parents and trashed = false",
      fields: "files(id,name,createdTime)",
      supports_all_drives: true,
      include_items_from_all_drives: true
    )

    (response.files || []).filter_map do |file|
      next unless file.name&.match?(self.class.backup_name_pattern(@environment))

      BackupFile.new(
        id: file.id,
        name: file.name,
        created_time: file.created_time
      )
    end
  end

  def delete(file_id)
    metadata = Google::Apis::DriveV3::File.new(trashed: true)
    @drive_service.update_file(
      file_id,
      metadata,
      supports_all_drives: true
    )
  rescue Google::Apis::ClientError => e
    raise unless e.status_code == 404

    nil
  end

  def download(file_id, dest_path)
    @drive_service.get_file(file_id, download_dest: dest_path, supports_all_drives: true)
  end

  def find_by_name(name)
    response = @drive_service.list_files(
      q: "name = '#{escape_drive_query(name)}' and '#{folder_id}' in parents and trashed = false",
      fields: "files(id,name,createdTime)",
      supports_all_drives: true,
      include_items_from_all_drives: true
    )

    file = (response.files || []).first
    return unless file

    BackupFile.new(
      id: file.id,
      name: file.name,
      created_time: file.created_time
    )
  end

  private

  def escape_drive_query(value)
    value.gsub("'", "\\'")
  end

  def folder_id
    ENV.fetch("GOOGLE_DRIVE_BACKUP_FOLDER_ID")
  end

  def build_drive_service
    key_path = ENV.fetch("GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH")
    raise Error, "Service account key file not found: #{key_path}" unless File.file?(key_path)

    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(key_path),
      scope: DRIVE_SCOPE
    )

    service = Google::Apis::DriveV3::DriveService.new
    service.authorization = credentials
    service
  end
end
