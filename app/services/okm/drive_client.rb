require "google/apis/drive_v3"
require "googleauth"
require "digest"

module Okm
  # Read-only access to the OKM shared drive. All API calls use supports_all_drives.
  class DriveClient
    Error = Class.new(StandardError)
    FileEntry = Data.define(:id, :name, :mime_type, :parent_id)
    SearchResult = Data.define(:id, :name, :mime_type, :parent_id)

    DRIVE_SCOPE = Google::Apis::DriveV3::AUTH_DRIVE_READONLY
    GOOGLE_DOC_MIME = "application/vnd.google-apps.document"
    GOOGLE_FOLDER_MIME = "application/vnd.google-apps.folder"
    TEXT_MIMES = %w[
      text/plain
      text/markdown
      text/x-markdown
      text/html
      application/json
    ].freeze
    BINARY_MIMES = %w[
      application/pdf
      application/vnd.openxmlformats-officedocument.presentationml.presentation
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    ].freeze

    def initialize(workspace:, drive_service: nil)
      @workspace = workspace
      raise Error, "OKM is not configured for this workspace" unless workspace.okm_configured?

      @drive_service = drive_service || build_drive_service
    end

    def search(text)
      query = sanitize_query(text)
      return [] if query.blank?

      cached = Rails.cache.fetch(search_cache_key(query), expires_in: Configuration.index_cache_ttl.seconds) do
        fetch_search_results(query).map { |result| serialize_entry(result) }
      end

      cached.map { |attrs| SearchResult.new(**attrs.transform_keys(&:to_sym)) }
    end

    def list_folder(folder_id)
      cached = Rails.cache.fetch(folder_cache_key(folder_id), expires_in: Configuration.index_cache_ttl.seconds) do
        fetch_folder_entries(folder_id).map { |entry| serialize_entry(entry) }
      end

      cached.map { |attrs| FileEntry.new(**attrs.transform_keys(&:to_sym)) }
    end

    def read_file(file_id)
      Rails.cache.fetch(cache_key(file_id), expires_in: Configuration.cache_ttl.seconds) do
        metadata = @drive_service.get_file(
          file_id,
          fields: "id,name,mimeType",
          supports_all_drives: true
        )
        content = download_content(metadata)
        truncate(content)
      end
    end

    private

    attr_reader :workspace

    def drive_id
      workspace.okm_drive_id
    end

    def sanitize_query(text)
      text.to_s.strip.gsub(/['\\]/, " ").squish.first(200)
    end

    def escape_drive_query(value)
      value.to_s.gsub("'", "\\'")
    end

    def cache_key(file_id)
      "okm/#{drive_id}/drive_file/#{file_id}"
    end

    def search_cache_key(query)
      "okm/#{drive_id}/search/#{Digest::SHA256.hexdigest(query)}"
    end

    def folder_cache_key(folder_id)
      "okm/#{drive_id}/folder/#{folder_id}"
    end

    def serialize_entry(entry)
      {
        "id" => entry.id,
        "name" => entry.name,
        "mime_type" => entry.mime_type,
        "parent_id" => entry.parent_id
      }
    end

    def fetch_search_results(query)
      escaped = escape_drive_query(query)
      q = [
        "trashed = false",
        "(fullText contains '#{escaped}' or name contains '#{escaped}')"
      ].join(" and ")

      response = @drive_service.list_files(
        q: q,
        corpora: "drive",
        drive_id: drive_id,
        include_items_from_all_drives: true,
        supports_all_drives: true,
        fields: "files(id,name,mimeType,parents)",
        page_size: Configuration.max_search_results
      )

      Array(response.files).map do |file|
        SearchResult.new(
          id: file.id,
          name: file.name,
          mime_type: file.mime_type,
          parent_id: file.parents&.first
        )
      end
    end

    def fetch_folder_entries(folder_id)
      response = @drive_service.list_files(
        q: "'#{escape_drive_query(folder_id)}' in parents and trashed = false",
        corpora: "drive",
        drive_id: drive_id,
        include_items_from_all_drives: true,
        supports_all_drives: true,
        fields: "files(id,name,mimeType,parents)",
        page_size: 100,
        order_by: "folder,name"
      )

      Array(response.files).map do |file|
        FileEntry.new(
          id: file.id,
          name: file.name,
          mime_type: file.mime_type,
          parent_id: file.parents&.first
        )
      end
    end

    def download_content(metadata)
      case metadata.mime_type
      when GOOGLE_DOC_MIME
        export_google_doc(metadata.id)
      when GOOGLE_FOLDER_MIME
        raise Error, "#{metadata.name} is a folder, not a file."
      when *BINARY_MIMES
        raise Error, "#{metadata.name} is a binary file (#{metadata.mime_type}); cannot read as text."
      else
        download_binary(metadata.id)
      end
    end

    def export_google_doc(file_id)
      io = StringIO.new
      @drive_service.export_file(
        file_id,
        "text/plain",
        download_dest: io
      )
      io.string
    end

    def download_binary(file_id)
      io = StringIO.new
      @drive_service.get_file(file_id, download_dest: io, supports_all_drives: true)
      io.string.force_encoding(Encoding::UTF_8)
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      io.string.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
    end

    def truncate(content)
      limit = Configuration.max_file_chars
      text = content.to_s
      return text if text.length <= limit

      "#{text.first(limit)}\n\n[truncated]"
    end

    def build_drive_service
      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(workspace.okm_service_account_key),
        scope: DRIVE_SCOPE
      )

      service = Google::Apis::DriveV3::DriveService.new
      service.authorization = credentials
      service
    end
  end
end
