require "rails_helper"

RSpec.describe DatabaseRestoreService do
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
    allow(storage).to receive(:download)
    allow(service).to receive(:run_pg_restore)
  end

  it "restores the latest backup for the environment when no file name is given" do
    older = backup_file("cream_backup_test_2026-06-01.dump")
    newer = backup_file("cream_backup_test_2026-07-01.dump")
    allow(storage).to receive(:list_backups).and_return([older, newer])

    result = service.call

    expect(storage).to have_received(:download).with(newer.id, kind_of(String))
    expect(service).to have_received(:run_pg_restore).with(kind_of(String))
    expect(result.restored_file_name).to eq("cream_backup_test_2026-07-01.dump")
  end

  it "restores a specific backup by file name" do
    backup = backup_file("cream_backup_production_2026-07-01.dump")
    allow(storage).to receive(:find_by_name).with("cream_backup_production_2026-07-01.dump").and_return(backup)

    result = service.call(file_name: "cream_backup_production_2026-07-01.dump")

    expect(storage).to have_received(:download).with(backup.id, kind_of(String))
    expect(result.restored_file_name).to eq("cream_backup_production_2026-07-01.dump")
  end

  it "raises when there are no backups for the environment" do
    allow(storage).to receive(:list_backups).and_return([])

    expect { service.call }.to raise_error(DatabaseRestoreService::Error, /No backups found/)
  end

  it "raises when the requested backup does not exist" do
    allow(storage).to receive(:find_by_name).with("missing.dump").and_return(nil)

    expect { service.call(file_name: "missing.dump") }
      .to raise_error(DatabaseRestoreService::Error, /Backup not found in Drive/)
  end

  it "decrypts age backups before pg_restore" do
    encrypted = backup_file("cream_backup_test_2026-07-01.dump.age")
    allow(storage).to receive(:list_backups).and_return([encrypted])
    allow(DatabaseBackupAge).to receive(:decrypt_if_needed).and_return("/tmp/decrypted.dump")

    service.call

    expect(DatabaseBackupAge).to have_received(:decrypt_if_needed).with(kind_of(String), encrypted.name)
    expect(service).to have_received(:run_pg_restore).with("/tmp/decrypted.dump")
  end

  it "deletes the decrypted dump after restoring" do
    encrypted = backup_file("cream_backup_test_2026-07-01.dump.age")
    allow(storage).to receive(:list_backups).and_return([encrypted])
    decrypted_path = nil
    allow(DatabaseBackupAge).to receive(:decrypt_if_needed) do |path, _name|
      decrypted_path = "#{path}.decrypted.dump"
      File.write(decrypted_path, "plain")
      decrypted_path
    end

    service.call

    expect(service).to have_received(:run_pg_restore).with(decrypted_path)
    expect(File.exist?(decrypted_path)).to be(false)
  end

  it "restores the latest backup whether or not it is encrypted" do
    older_plain = backup_file("cream_backup_test_2026-06-30.dump")
    newer_encrypted = backup_file("cream_backup_test_2026-07-01.dump.age")
    allow(storage).to receive(:list_backups).and_return([newer_encrypted, older_plain])
    allow(DatabaseBackupAge).to receive(:decrypt_if_needed).and_return("/tmp/decrypted.dump")

    expect(service.call.restored_file_name).to eq(newer_encrypted.name)
  end

  it "does not decrypt plain .dump backups" do
    plain = backup_file("cream_backup_test_2026-07-01.dump")
    allow(storage).to receive(:list_backups).and_return([plain])
    allow(DatabaseBackupAge).to receive(:decrypt_if_needed).and_call_original

    service.call

    expect(service).to have_received(:run_pg_restore).with(kind_of(String))
  end

  it "raises when pg_restore fails" do
    allow(storage).to receive(:list_backups).and_return([backup_file("cream_backup_test_2026-07-01.dump")])
    allow(service).to receive(:run_pg_restore).and_call_original
    allow(Open3).to receive(:capture3).and_return(["", "restore failed", instance_double(Process::Status, success?: false, exitstatus: 1)])

    expect { service.call }.to raise_error(DatabaseRestoreService::Error, /pg_restore failed/)
  end
end
