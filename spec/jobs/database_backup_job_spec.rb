require "rails_helper"

RSpec.describe DatabaseBackupJob do
  let(:result) do
    DatabaseBackupService::Result.new(
      uploaded_file_name: "cream_backup_production_2026-07-02.dump",
      deleted_files: [ "cream_backup_production_2026-05-15.dump" ]
    )
  end

  it "runs the backup service when Google Drive is configured in production" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH").and_return("/tmp/cream-backup.json")
    allow(ENV).to receive(:[]).with("GOOGLE_DRIVE_BACKUP_FOLDER_ID").and_return("folder123")
    allow(File).to receive(:file?).with("/tmp/cream-backup.json").and_return(true)
    service = instance_double(DatabaseBackupService, call: result)
    allow(DatabaseBackupService).to receive(:new).and_return(service)

    described_class.perform_now

    expect(service).to have_received(:call)
  end

  it "skips outside production even when Google Drive is configured" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH").and_return("/tmp/cream-backup.json")
    allow(ENV).to receive(:[]).with("GOOGLE_DRIVE_BACKUP_FOLDER_ID").and_return("folder123")
    allow(File).to receive(:file?).with("/tmp/cream-backup.json").and_return(true)
    allow(DatabaseBackupService).to receive(:new)

    described_class.perform_now

    expect(DatabaseBackupService).not_to have_received(:new)
  end

  it "skips when Google Drive is not configured" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH").and_return(nil)
    allow(ENV).to receive(:[]).with("GOOGLE_DRIVE_BACKUP_FOLDER_ID").and_return(nil)
    allow(DatabaseBackupService).to receive(:new)

    described_class.perform_now

    expect(DatabaseBackupService).not_to have_received(:new)
  end
end
