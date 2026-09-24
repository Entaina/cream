require "net/http"
require "json"

# Reads Gmail inbox metadata (headers only) for reply detection. Uses Net::HTTP so
# specs can stub requests without calling Google.
class GmailReader
  include GmailTokenRefresh

  Error = Class.new(StandardError)
  Metadata = Data.define(:id, :thread_id, :label_ids, :from, :subject, :in_reply_to, :references, :message_id, :internal_date)
  FullMessage = Data.define(:id, :thread_id, :label_ids, :from, :subject, :snippet, :body_text, :message_id, :date)

  BASE_URI = "https://gmail.googleapis.com/gmail/v1/users/me/messages"
  THREAD_URI = "https://gmail.googleapis.com/gmail/v1/users/me/threads"
  METADATA_HEADERS = %w[From Subject In-Reply-To References Message-Id].freeze
  INBOX_LIST_MAX_PAGES = 2

  def initialize(connection)
    @connection = connection
  end

  def list_recent_message_ids(after:)
    bearer = ensure_sync_access_token!(@connection)
    ids = []
    page_token = nil
    pages = 0

    loop do
      uri = if metadata_scope_restricts_search?
        URI("#{BASE_URI}?labelIds=INBOX&maxResults=100")
      else
        query = build_query(after)
        URI("#{BASE_URI}?q=#{URI.encode_www_form_component(query)}&maxResults=100")
      end
      uri.query += "&pageToken=#{page_token}" if page_token.present?

      response = get_json(uri, bearer: bearer)
      raise Error, "list failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      ids.concat(Array(data["messages"]).map { |row| row["id"] })
      page_token = data["nextPageToken"]
      pages += 1
      break if page_token.blank?
      break if metadata_scope_restricts_search? && pages >= INBOX_LIST_MAX_PAGES
    end

    ids
  end

  def get_thread_metadata(thread_id)
    bearer = ensure_sync_access_token!(@connection)
    uri = URI("#{THREAD_URI}/#{thread_id}?format=metadata&#{metadata_headers_query}")

    response = get_json(uri, bearer: bearer)
    raise Error, "thread get failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    Array(JSON.parse(response.body)["messages"]).map { |message| parse_metadata(message) }
  end

  def get_metadata(id)
    bearer = ensure_sync_access_token!(@connection)
    uri = URI("#{BASE_URI}/#{id}?format=metadata&#{metadata_headers_query}")

    response = get_json(uri, bearer: bearer)
    raise Error, "get failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    parse_metadata(JSON.parse(response.body))
  end

  def get_full(id)
    bearer = ensure_sync_access_token!(@connection)
    uri = URI("#{BASE_URI}/#{id}?format=full")

    response = get_json(uri, bearer: bearer)
    raise Error, "get full failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    parse_full(JSON.parse(response.body))
  end

  private

  def build_query(after)
    parts = ["-in:sent"]
    parts << "after:#{after.to_i}" if after.present?
    parts.join(" ")
  end

  def parse_metadata(data)
    headers = extract_headers(data)

    Metadata.new(
      id: data["id"],
      thread_id: data["threadId"],
      label_ids: Array(data["labelIds"]),
      from: headers["From"],
      subject: headers["Subject"],
      in_reply_to: headers["In-Reply-To"],
      references: headers["References"],
      message_id: headers["Message-Id"],
      internal_date: data["internalDate"].to_i
    )
  end

  def metadata_scope_restricts_search?
    @connection.scopes.include?(GmailConnection::METADATA_SCOPE)
  end

  def metadata_headers_query
    URI.encode_www_form(METADATA_HEADERS.map { |header| ["metadataHeaders", header] })
  end

  def parse_full(data)
    headers = extract_headers(data)
    snippet = data["snippet"].to_s

    FullMessage.new(
      id: data["id"],
      thread_id: data["threadId"],
      label_ids: Array(data["labelIds"]),
      from: headers["From"],
      subject: headers["Subject"],
      snippet: snippet,
      body_text: extract_body_text(data["payload"], snippet),
      message_id: headers["Message-Id"],
      date: headers["Date"]
    )
  end

  def extract_headers(data)
    Array(data.dig("payload", "headers")).each_with_object({}) do |header, hash|
      hash[header["name"]] = header["value"]
    end
  end

  def extract_body_text(payload, snippet)
    html = find_part_body(payload, "text/html")
    return html if html.present?

    plain = find_part_body(payload, "text/plain")
    return plain if plain.present?

    single = decode_body(payload)
    return single if single.present?

    snippet
  end

  def find_part_body(part, mime_type)
    return decode_body(part) if part["mimeType"] == mime_type

    Array(part["parts"]).each do |child|
      body = find_part_body(child, mime_type)
      return body if body.present?
    end

    nil
  end

  def decode_body(part)
    data = part.dig("body", "data")
    return nil if data.blank?

    Base64.urlsafe_decode64(data)
  rescue ArgumentError
    nil
  end
end
