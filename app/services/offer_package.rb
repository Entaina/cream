# Validates and reads HTML offer packages stored as ZIP files (index + relative assets).
require "zip"

class OfferPackage
  MAX_ENTRIES = 2000
  MAX_UNCOMPRESSED_BYTES = 200.megabytes

  Entry = Data.define(:entry_path)
  Failure = Data.define(:error_key)

  class << self
    def detect_entry(io)
      io.rewind if io.respond_to?(:rewind)
      html_paths = []
      entry_count = 0
      total_uncompressed = 0

      ::Zip::File.open_buffer(io) do |zip|
        zip.each do |entry|
          next if skip_entry?(entry.name)

          entry_count += 1
          return Failure.new(error_key: :offer_zip_limits) if entry_count > MAX_ENTRIES

          total_uncompressed += entry.size
          return Failure.new(error_key: :offer_zip_limits) if total_uncompressed > MAX_UNCOMPRESSED_BYTES

          html_paths << entry.name if html_file?(entry.name)
        end
      end

      picked = pick_entry(html_paths)
      return Failure.new(error_key: :offer_zip_entry_not_found) if picked.blank?

      Entry.new(entry_path: picked)
    rescue ::Zip::Error
      Failure.new(error_key: :offer_zip_invalid)
    end

    def read(blob, path)
      blob.open do |tempfile|
        ::Zip::File.open(tempfile.path) do |zip|
          entry = zip.find_entry(path)
          return nil unless entry

          entry.get_input_stream.read
        end
      end
    end

    def html_file?(path)
      !path.end_with?("/") && path.match?(/\.html?\z/i)
    end

    SANDBOX_STORAGE_SHIM = <<~JS.freeze
      <script>
      (function () {
        function memoryStorage() {
          var store = Object.create(null);
          return {
            get length() { return Object.keys(store).length; },
            clear: function () { store = Object.create(null); },
            getItem: function (key) { return Object.prototype.hasOwnProperty.call(store, key) ? store[key] : null; },
            key: function (index) { return Object.keys(store)[index] || null; },
            setItem: function (key, value) { store[String(key)] = String(value); },
            removeItem: function (key) { delete store[String(key)]; }
          };
        }
        try {
          localStorage.setItem("__cream_offer_probe", "1");
          localStorage.removeItem("__cream_offer_probe");
          return;
        } catch (error) {}
        Object.defineProperty(window, "localStorage", {value: memoryStorage(), configurable: true});
        Object.defineProperty(window, "sessionStorage", {value: memoryStorage(), configurable: true});
      })();
      </script>
    JS

    # Zip exports often ship <base href="/">, which makes relative assets load from the CRM root (/app.js).
    def rewrite_html_for_preview(html, entry_path:, base_href:)
      doc = html.to_s.dup.force_encoding(Encoding::UTF_8)
      doc = doc.gsub(/<base\b[^>]*>/i, "")
      doc = doc.sub(/<head(\s[^>]*)?>/i) do
        "#{Regexp.last_match(0)}<base href=\"#{ERB::Util.html_escape(base_href)}\">#{SANDBOX_STORAGE_SHIM}"
      end
      doc.gsub(/(\s(?:src|href)\s*=\s*["'])\/(?!\/)([^"']*)(["'])/i) do
        prefix = Regexp.last_match(1)
        asset = Regexp.last_match(2)
        suffix = Regexp.last_match(3)
        relative = relative_asset_path(entry_path, asset)
        "#{prefix}#{relative}#{suffix}"
      end
    end

    def content_type_for(path)
      case File.extname(path).downcase
      when ".js", ".mjs" then "text/javascript"
      when ".css" then "text/css"
      when ".html", ".htm" then "text/html"
      when ".svg" then "image/svg+xml"
      when ".json" then "application/json"
      when ".wasm" then "application/wasm"
      else Marcel::MimeType.for(name: path)
      end
    end

    private

    def relative_asset_path(entry_path, absolute_path)
      path_part, query = absolute_path.split("?", 2)
      from_dir = File.dirname(entry_path)
      from = Pathname.new((from_dir == ".") ? "" : from_dir)
      relative = Pathname.new(path_part).relative_path_from(from).to_s
      query ? "#{relative}?#{query}" : relative
    end

    def skip_entry?(name)
      name.start_with?("__MACOSX/") || name.include?("/.") || name.start_with?(".")
    end

    def pick_entry(html_paths)
      index_files = html_paths.select { |path| File.basename(path).match?(/\Aindex\.html?\z/i) }
      return index_files.min_by { |path| path.count("/") } if index_files.any?
      return html_paths.first if html_paths.one?

      nil
    end
  end
end
