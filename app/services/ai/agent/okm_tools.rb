module Ai
  module Agent
    # Read-only OKM Drive tools and prefetch helpers.
    class OkmTools
      TOOLS = [
        {
          type: "function",
          name: "search_okm",
          description: "Search the OKM knowledge base by keyword or phrase.",
          parameters: {
            type: "object",
            properties: {
              query: {type: "string", description: "Search terms (company name, person, topic, product)"}
            },
            required: ["query"],
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "list_okm_folder",
          description: "List files and subfolders inside an OKM Drive folder (use after search to explore).",
          parameters: {
            type: "object",
            properties: {
              folder_id: {type: "string", description: "Google Drive folder ID"}
            },
            required: ["folder_id"],
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "read_okm_file",
          description: "Read the text content of an OKM markdown or document file.",
          parameters: {
            type: "object",
            properties: {
              file_id: {type: "string", description: "Google Drive file ID"}
            },
            required: ["file_id"],
            additionalProperties: false
          }
        }
      ].freeze

      MAX_PREFETCH_QUERIES = 2
      MAX_PREFETCH_READS = 2

      def initialize(drive:, on_status: nil)
        @drive = drive
        @on_status = on_status
      end

      def definitions
        TOOLS
      end

      def try_execute(name, args)
        case name
        when "search_okm" then execute_search(args)
        when "list_okm_folder" then execute_list_folder(args)
        when "read_okm_file" then execute_read_file(args)
        end
      end

      def prefetch(record:, message:)
        sections = []
        reads = 0

        prefetch_queries(record, message).each do |query|
          notify("Buscando en el OKM: #{query}…")
          results = @drive.search(query)
          next if results.empty?

          sections << "### Búsqueda OKM: #{query}\n#{results.map { |r| format_entry(r) }.join("\n")}"

          results.each do |entry|
            break if reads >= MAX_PREFETCH_READS
            next if entry.mime_type == Okm::DriveClient::GOOGLE_FOLDER_MIME
            next unless prefetchable_file?(entry.name)

            notify("Leyendo #{entry.name}…")
            sections << "### #{entry.name}\n#{@drive.read_file(entry.id)}"
            reads += 1
          rescue Okm::DriveClient::Error, Google::Apis::Error
            next
          end
        end

        sections.join("\n\n")
      rescue Okm::DriveClient::Error, Google::Apis::Error
        ""
      end

      private

      def execute_search(args)
        notify("Buscando en el OKM: #{args["query"].presence || "…"}…")
        results = @drive.search(args["query"])
        results.empty? ? "No files found." : results.map { |r| format_entry(r) }.join("\n")
      rescue Okm::DriveClient::Error, Google::Apis::Error => e
        "Error: #{e.message}"
      end

      def execute_list_folder(args)
        notify("Explorando carpeta del OKM…")
        entries = @drive.list_folder(args["folder_id"])
        entries.empty? ? "Folder is empty." : entries.map { |e| format_entry(e) }.join("\n")
      rescue Okm::DriveClient::Error, Google::Apis::Error => e
        "Error: #{e.message}"
      end

      def execute_read_file(args)
        notify("Leyendo documento del OKM…")
        @drive.read_file(args["file_id"])
      rescue Okm::DriveClient::Error, Google::Apis::Error => e
        "Error: #{e.message}"
      end

      def prefetch_queries(record, message)
        terms = record_prefetch_terms(record)
        terms << message if terms.empty? && message.length <= 120
        terms.compact.map(&:strip).reject(&:blank?).uniq.first(MAX_PREFETCH_QUERIES)
      end

      def record_prefetch_terms(record)
        case record
        when Company
          [record.name, record.domain]
        when Person
          [record.company&.name, record.display_name]
        when Deal
          [record.company&.name]
        else
          []
        end
      end

      def prefetchable_file?(name)
        down = name.downcase
        down.end_with?(".md", ".txt", ".html") || down.include?("contexto") || down == "index.md"
      end

      def format_entry(entry)
        kind = (entry.mime_type == Okm::DriveClient::GOOGLE_FOLDER_MIME) ? "folder" : "file"
        parent = entry.parent_id ? " parent=#{entry.parent_id}" : ""
        "#{kind} id=#{entry.id} name=#{entry.name} mime=#{entry.mime_type}#{parent}"
      end

      def notify(message)
        @on_status&.call(message)
      end
    end
  end
end
