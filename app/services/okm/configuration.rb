module Okm
  # Reads OKM Google Drive settings from the environment.
  class Configuration
    def self.configured?
      drive_id.present? && service_account_key_path.present? && File.file?(service_account_key_path)
    end

    def self.drive_id
      ENV["OKM_DRIVE_ID"].presence
    end

    def self.service_account_key_path
      ENV.fetch("GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH", nil).presence
    end

    def self.cache_ttl
      ENV.fetch("OKM_CACHE_TTL", "3600").to_i
    end

    def self.index_cache_ttl
      ENV.fetch("OKM_INDEX_CACHE_TTL", "600").to_i
    end

    def self.max_file_chars
      ENV.fetch("OKM_MAX_FILE_CHARS", "20000").to_i
    end

    def self.max_search_results
      ENV.fetch("OKM_MAX_SEARCH_RESULTS", "15").to_i
    end
  end
end
