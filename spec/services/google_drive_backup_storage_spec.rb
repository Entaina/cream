require "rails_helper"

RSpec.describe GoogleDriveBackupStorage do
  let(:drive_service) { instance_double(Google::Apis::DriveV3::DriveService) }
  let(:storage) { described_class.new(drive_service: drive_service, environment: "test") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("GOOGLE_DRIVE_BACKUP_FOLDER_ID").and_return("folder123")
  end

  describe "#upload" do
    it "uploads a file to the configured folder" do
      uploaded = instance_double(Google::Apis::DriveV3::File, id: "file1")
      allow(drive_service).to receive(:create_file).and_return(uploaded)

      result = storage.upload("/tmp/backup.dump", name: "cream_backup_test_2026-07-02.dump")

      expect(result).to eq(uploaded)
      expect(drive_service).to have_received(:create_file).with(
        an_object_having_attributes(name: "cream_backup_test_2026-07-02.dump", parents: ["folder123"]),
        supports_all_drives: true,
        upload_source: "/tmp/backup.dump",
        content_type: "application/octet-stream"
      )
    end
  end

  describe ".backup_name_pattern" do
    it "matches plain and age-encrypted dumps of the environment only" do
      pattern = described_class.backup_name_pattern("test")

      expect("cream_backup_test_2026-06-01.dump").to match(pattern)
      expect("cream_backup_test_2026-06-01.dump.age").to match(pattern)
      expect("cream_backup_test_2026-06-01.dump.gpg").not_to match(pattern)
      expect("cream_backup_production_2026-06-01.dump.age").not_to match(pattern)
    end
  end

  describe "#list_backups" do
    it "returns only cream backup files from the folder" do
      backup = instance_double(
        Google::Apis::DriveV3::File,
        id: "file1",
        name: "cream_backup_test_2026-06-01.dump",
        created_time: Time.zone.parse("2026-06-01 02:00:00")
      )
      other = instance_double(
        Google::Apis::DriveV3::File,
        id: "file2",
        name: "notes.txt",
        created_time: Time.zone.parse("2026-06-01 02:00:00")
      )
      response = instance_double(Google::Apis::DriveV3::FileList, files: [backup, other])
      allow(drive_service).to receive(:list_files).and_return(response)

      files = storage.list_backups

      expect(files).to eq([
        described_class::BackupFile.new(
          id: "file1",
          name: "cream_backup_test_2026-06-01.dump",
          created_time: backup.created_time
        )
      ])
      expect(drive_service).to have_received(:list_files).with(
        q: "'folder123' in parents and trashed = false",
        fields: "files(id,name,createdTime)",
        supports_all_drives: true,
        include_items_from_all_drives: true
      )
    end
  end

  describe "#delete" do
    it "deletes a file from Drive" do
      allow(drive_service).to receive(:delete_file)

      storage.delete("file1")

      expect(drive_service).to have_received(:delete_file).with("file1", supports_all_drives: true)
    end
  end

  describe "#download" do
    it "downloads a file from Drive to the given path" do
      allow(drive_service).to receive(:get_file)

      storage.download("file1", "/tmp/backup.dump")

      expect(drive_service).to have_received(:get_file).with(
        "file1",
        download_dest: "/tmp/backup.dump",
        supports_all_drives: true
      )
    end
  end

  describe "#find_by_name" do
    it "returns a backup file when it exists in the folder" do
      backup = instance_double(
        Google::Apis::DriveV3::File,
        id: "file1",
        name: "cream_backup_production_2026-07-01.dump",
        created_time: Time.zone.parse("2026-07-01 02:00:00")
      )
      response = instance_double(Google::Apis::DriveV3::FileList, files: [backup])
      allow(drive_service).to receive(:list_files).and_return(response)

      result = storage.find_by_name("cream_backup_production_2026-07-01.dump")

      expect(result).to eq(
        described_class::BackupFile.new(
          id: "file1",
          name: "cream_backup_production_2026-07-01.dump",
          created_time: backup.created_time
        )
      )
      expect(drive_service).to have_received(:list_files).with(
        q: "name = 'cream_backup_production_2026-07-01.dump' and 'folder123' in parents and trashed = false",
        fields: "files(id,name,createdTime)",
        supports_all_drives: true,
        include_items_from_all_drives: true
      )
    end

    it "returns nil when the file does not exist" do
      response = instance_double(Google::Apis::DriveV3::FileList, files: [])
      allow(drive_service).to receive(:list_files).and_return(response)

      expect(storage.find_by_name("missing.dump")).to be_nil
    end
  end

  describe ".new without injected drive_service" do
    it "loads credentials from the service account key file" do
      key_path = Rails.root.join("tmp/test-service-account.json")
      FileUtils.mkdir_p(key_path.dirname)
      File.write(key_path, '{"type":"service_account"}')
      credentials = instance_double(Google::Auth::ServiceAccountCredentials)
      drive = instance_double(Google::Apis::DriveV3::DriveService)
      allow(drive).to receive(:authorization=)
      allow(ENV).to receive(:fetch).with("GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH").and_return(key_path.to_s)
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(credentials)
      allow(Google::Apis::DriveV3::DriveService).to receive(:new).and_return(drive)

      described_class.new

      expect(Google::Auth::ServiceAccountCredentials).to have_received(:make_creds).with(
        json_key_io: kind_of(File),
        scope: GoogleDriveBackupStorage::DRIVE_SCOPE
      )
    ensure
      File.delete(key_path) if File.exist?(key_path)
    end

    it "raises when the service account key file is missing" do
      allow(ENV).to receive(:fetch).with("GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH").and_return("/missing/key.json")

      expect { described_class.new }.to raise_error(GoogleDriveBackupStorage::Error, /not found/)
    end
  end
end
