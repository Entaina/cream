require "rails_helper"

RSpec.describe DatabaseBackupAge do
  describe ".encrypted_name?" do
    it "detects age suffix" do
      expect(described_class.encrypted_name?("cream_backup_production_2026-01-01.dump.age")).to be(true)
      expect(described_class.encrypted_name?("cream_backup_production_2026-01-01.dump")).to be(false)
    end
  end

  describe ".decrypt_if_needed" do
    it "returns the same path for plain dumps" do
      path = "/tmp/backup.dump"
      expect(described_class.decrypt_if_needed(path, "cream_backup_test_2026-01-01.dump")).to eq(path)
    end

    it "raises when encrypted but identity is missing" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("BACKUP_AGE_IDENTITY_FILE").and_return(nil)
      allow(ENV).to receive(:[]).with("BACKUP_AGE_IDENTITY").and_return(nil)

      expect {
        described_class.decrypt_if_needed("/tmp/x.dump", "cream_backup_test_2026-01-01.dump.age")
      }.to raise_error(DatabaseBackupAge::Error, /BACKUP_AGE_IDENTITY/)
    end

    context "with an encrypted backup" do
      let(:success) { instance_double(Process::Status, success?: true) }
      let(:failure) { instance_double(Process::Status, success?: false) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("BACKUP_AGE_IDENTITY_FILE").and_return(nil)
      end

      it "writes BACKUP_AGE_IDENTITY to a temporary identity file and removes it afterwards" do
        allow(ENV).to receive(:[]).with("BACKUP_AGE_IDENTITY").and_return("AGE-SECRET-KEY-1TEST")
        identity_path = nil
        allow(Open3).to receive(:capture3) do |*args|
          identity_path = args[args.index("-i") + 1]
          expect(File.read(identity_path)).to eq("AGE-SECRET-KEY-1TEST")
          ["", "", success]
        end

        result = described_class.decrypt_if_needed("/tmp/x.dump", "cream_backup_test_2026-01-01.dump.age")

        expect(result).to eq("/tmp/x.dump.decrypted.dump")
        expect(Open3).to have_received(:capture3).with(
          "age", "-d", "-i", identity_path, "-o", "/tmp/x.dump.decrypted.dump", "/tmp/x.dump"
        )
        expect(File.exist?(identity_path)).to be(false)
      end

      it "uses BACKUP_AGE_IDENTITY_FILE when configured and leaves it in place" do
        identity = Tempfile.new("identity")
        identity.write("AGE-SECRET-KEY-1FILE")
        identity.flush
        allow(ENV).to receive(:[]).with("BACKUP_AGE_IDENTITY_FILE").and_return(identity.path)
        allow(Open3).to receive(:capture3).and_return(["", "", success])

        described_class.decrypt_if_needed("/tmp/x.dump", "cream_backup_test_2026-01-01.dump.age")

        expect(Open3).to have_received(:capture3).with(
          "age", "-d", "-i", identity.path, "-o", "/tmp/x.dump.decrypted.dump", "/tmp/x.dump"
        )
        expect(File.exist?(identity.path)).to be(true)
      ensure
        identity&.close!
      end

      it "raises and removes the partial output when age fails" do
        allow(ENV).to receive(:[]).with("BACKUP_AGE_IDENTITY").and_return("AGE-SECRET-KEY-1TEST")
        source = Tempfile.new("backup")
        decrypted_path = "#{source.path}.decrypted.dump"
        allow(Open3).to receive(:capture3) do
          File.write(decrypted_path, "partial")
          ["", "bad key", failure]
        end

        expect {
          described_class.decrypt_if_needed(source.path, "cream_backup_test_2026-01-01.dump.age")
        }.to raise_error(DatabaseBackupAge::Error, /bad key/)
        expect(File.exist?(decrypted_path)).to be(false)
      ensure
        source&.close!
      end
    end
  end

  describe ".encrypt_if_configured" do
    before { allow(ENV).to receive(:[]).and_call_original }

    it "returns the plain dump when no public key is configured" do
      allow(ENV).to receive(:[]).with("BACKUP_AGE_PUBLIC_KEY").and_return(nil)

      expect(described_class.encrypt_if_configured("/tmp/x.dump", "b.dump")).to eq(["/tmp/x.dump", "b.dump"])
    end

    it "encrypts with the configured recipient and appends .age to the name" do
      allow(ENV).to receive(:[]).with("BACKUP_AGE_PUBLIC_KEY").and_return("age1recipient")
      allow(Open3).to receive(:capture3).and_return(["", "", instance_double(Process::Status, success?: true)])

      expect(described_class.encrypt_if_configured("/tmp/x.dump", "b.dump")).to eq(["/tmp/x.dump.age", "b.dump.age"])
      expect(Open3).to have_received(:capture3).with("age", "-r", "age1recipient", "-o", "/tmp/x.dump.age", "/tmp/x.dump")
    end
  end
end
