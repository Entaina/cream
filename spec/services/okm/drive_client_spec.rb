require "rails_helper"

RSpec.describe Okm::DriveClient do
  let(:drive_service) { instance_double(Google::Apis::DriveV3::DriveService) }
  let(:client) { described_class.new(drive_service: drive_service) }
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Okm::Configuration).to receive_messages(
      drive_id: "drive123",
      cache_ttl: 3600,
      index_cache_ttl: 600,
      max_file_chars: 100,
      max_search_results: 5
    )
    allow(Rails).to receive(:cache).and_return(memory_cache)
    memory_cache.clear
  end

  describe "#search" do
    it "returns matching files from the OKM drive" do
      file = instance_double(
        Google::Apis::DriveV3::File,
        id: "f1",
        name: "KaleQ.md",
        mime_type: "text/markdown",
        parents: [ "folder1" ]
      )
      response = instance_double(Google::Apis::DriveV3::FileList, files: [ file ])
      allow(drive_service).to receive(:list_files).and_return(response)

      results = client.search("KaleQ")

      expect(results.size).to eq(1)
      expect(results.first).to have_attributes(id: "f1", name: "KaleQ.md")
      expect(drive_service).to have_received(:list_files).with(
        hash_including(
          corpora: "drive",
          drive_id: "drive123",
          supports_all_drives: true,
          include_items_from_all_drives: true
        )
      )
    end

    it "returns an empty array for blank queries" do
      expect(client.search("   ")).to eq([])
      expect(drive_service).not_to have_received(:list_files) if drive_service.respond_to?(:list_files)
    end

    it "caches search results for the same query" do
      file = instance_double(
        Google::Apis::DriveV3::File,
        id: "f1",
        name: "KaleQ.md",
        mime_type: "text/markdown",
        parents: [ "folder1" ]
      )
      response = instance_double(Google::Apis::DriveV3::FileList, files: [ file ])
      allow(drive_service).to receive(:list_files).and_return(response)

      client.search("KaleQ")
      client.search("KaleQ")

      expect(drive_service).to have_received(:list_files).once
    end

    it "uses separate cache entries for different queries" do
      file_a = instance_double(
        Google::Apis::DriveV3::File,
        id: "f1",
        name: "KaleQ.md",
        mime_type: "text/markdown",
        parents: [ "folder1" ]
      )
      file_b = instance_double(
        Google::Apis::DriveV3::File,
        id: "f2",
        name: "Acme.md",
        mime_type: "text/markdown",
        parents: [ "folder2" ]
      )
      allow(drive_service).to receive(:list_files).and_return(
        instance_double(Google::Apis::DriveV3::FileList, files: [ file_a ]),
        instance_double(Google::Apis::DriveV3::FileList, files: [ file_b ])
      )

      client.search("KaleQ")
      client.search("Acme")

      expect(drive_service).to have_received(:list_files).twice
    end
  end

  describe "#list_folder" do
    it "lists files inside a folder" do
      file = instance_double(
        Google::Apis::DriveV3::File,
        id: "f2",
        name: "index.md",
        mime_type: "text/markdown",
        parents: [ "folder1" ]
      )
      response = instance_double(Google::Apis::DriveV3::FileList, files: [ file ])
      allow(drive_service).to receive(:list_files).and_return(response)

      entries = client.list_folder("folder1")

      expect(entries.first.name).to eq("index.md")
    end

    it "caches folder listings" do
      file = instance_double(
        Google::Apis::DriveV3::File,
        id: "f2",
        name: "index.md",
        mime_type: "text/markdown",
        parents: [ "folder1" ]
      )
      response = instance_double(Google::Apis::DriveV3::FileList, files: [ file ])
      allow(drive_service).to receive(:list_files).and_return(response)

      client.list_folder("folder1")
      client.list_folder("folder1")

      expect(drive_service).to have_received(:list_files).once
    end
  end

  describe "#read_file" do
    it "downloads text file content" do
      metadata = instance_double(
        Google::Apis::DriveV3::File,
        id: "f3",
        name: "notes.md",
        mime_type: "text/markdown"
      )
      allow(drive_service).to receive(:get_file).and_return(metadata)
      allow(drive_service).to receive(:get_file).with("f3", download_dest: kind_of(StringIO), supports_all_drives: true) do |_id, opts|
        opts[:download_dest].write("Hello OKM")
      end

      expect(client.read_file("f3")).to eq("Hello OKM")
    end

    it "exports Google Docs as plain text" do
      metadata = instance_double(
        Google::Apis::DriveV3::File,
        id: "doc1",
        name: "Brief",
        mime_type: described_class::GOOGLE_DOC_MIME
      )
      allow(drive_service).to receive(:get_file).and_return(metadata)
      allow(drive_service).to receive(:export_file) do |_id, _mime, opts|
        opts[:download_dest].write("Doc body")
      end

      expect(client.read_file("doc1")).to eq("Doc body")
    end

    it "rejects binary files" do
      metadata = instance_double(
        Google::Apis::DriveV3::File,
        id: "pdf1",
        name: "deck.pdf",
        mime_type: "application/pdf"
      )
      allow(drive_service).to receive(:get_file).and_return(metadata)

      expect { client.read_file("pdf1") }.to raise_error(Okm::DriveClient::Error, /binary file/)
    end

    it "truncates long content" do
      metadata = instance_double(
        Google::Apis::DriveV3::File,
        id: "f4",
        name: "long.md",
        mime_type: "text/markdown"
      )
      allow(drive_service).to receive(:get_file).and_return(metadata)
      allow(drive_service).to receive(:get_file).with("f4", download_dest: kind_of(StringIO), supports_all_drives: true) do |_id, opts|
        opts[:download_dest].write("x" * 200)
      end

      expect(client.read_file("f4")).to end_with("[truncated]")
    end

    it "caches file content" do
      metadata = instance_double(
        Google::Apis::DriveV3::File,
        id: "f3",
        name: "notes.md",
        mime_type: "text/markdown"
      )
      allow(drive_service).to receive(:get_file).and_return(metadata)
      allow(drive_service).to receive(:get_file).with("f3", download_dest: kind_of(StringIO), supports_all_drives: true) do |_id, opts|
        opts[:download_dest].write("Hello OKM")
      end

      client.read_file("f3")
      client.read_file("f3")

      expect(drive_service).to have_received(:get_file).with(
        "f3",
        fields: "id,name,mimeType",
        supports_all_drives: true
      ).once
    end
  end
end
