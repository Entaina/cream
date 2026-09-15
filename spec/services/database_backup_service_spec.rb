require "rails_helper"

RSpec.describe DatabaseBackupService do
  include ActiveSupport::Testing::TimeHelpers

  let(:storage) { instance_double(GoogleDriveBackupStorage) }
  let(:db_config) do
    instance_double(
      ActiveRecord::DatabaseConfigurations::HashConfig,
      configuration_hash: {
        host: "localhost",
        port: 5470,
        username: "cream",
        password: "secret",
        database: "cream_development"
      }
    )
  end
  let(:service) { described_class.new(storage: storage, db_config: db_config, environment: "test") }

  def backup_file(name, created_time: nil)
    GoogleDriveBackupStorage::BackupFile.new(
      id: "id-#{name}",
      name: name,
      created_time: created_time
    )
  end

  before do
    allow(storage).to receive(:upload)
    allow(storage).to receive(:list_backups).and_return([])
    allow(storage).to receive(:delete)
  end

  it "dumps the database, uploads it, and returns the result" do
    allow(service).to receive(:run_pg_dump) do |path|
      File.write(path, "dump-data")
    end

    travel_to Time.zone.parse("2026-07-02 02:00:00") do
      result = service.call

      expect(result.uploaded_file_name).to eq("cream_backup_test_2026-07-02.dump")
      expect(result.deleted_files).to eq([])
      expect(storage).to have_received(:upload).with(
        kind_of(String),
        name: "cream_backup_test_2026-07-02.dump"
      )
    end
  end

  it "raises when pg_dump fails" do
    allow(Open3).to receive(:capture3).and_return(["", "connection refused", instance_double(Process::Status, success?: false, exitstatus: 1)])

    expect { service.call }.to raise_error(DatabaseBackupService::Error, /pg_dump failed/)
  end

  it "deletes backups older than 30 days that are not from the 1st of the month" do
    allow(service).to receive(:run_pg_dump)
    old_daily = backup_file("cream_backup_test_2026-05-15.dump")
    old_monthly = backup_file("cream_backup_test_2026-05-01.dump")
    recent = backup_file("cream_backup_test_2026-06-20.dump")

    allow(storage).to receive(:list_backups).and_return([old_daily, old_monthly, recent])

    travel_to Time.zone.parse("2026-07-02 02:00:00") do
      result = service.call

      expect(storage).to have_received(:delete).with(old_daily.id)
      expect(storage).not_to have_received(:delete).with(old_monthly.id)
      expect(storage).not_to have_received(:delete).with(recent.id)
      expect(result.deleted_files).to eq(["cream_backup_test_2026-05-15.dump"])
    end
  end

  it "does not delete backups from other environments" do
    allow(service).to receive(:run_pg_dump)
    old_production = backup_file("cream_backup_production_2026-05-15.dump")

    allow(storage).to receive(:list_backups).and_return([old_production])

    travel_to Time.zone.parse("2026-07-02 02:00:00") do
      service.call
    end

    expect(storage).not_to have_received(:delete)
  end

  it "falls back to created_time when the filename does not match the backup pattern" do
    backup = backup_file("cream_backup_test_unknown.dump", created_time: Time.zone.parse("2026-05-15 02:00:00"))

    date = service.send(:backup_date_for, backup)

    expect(date).to eq(Date.new(2026, 5, 15))
  end
end
