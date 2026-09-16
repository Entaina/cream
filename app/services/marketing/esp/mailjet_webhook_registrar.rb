require "net/http"
require "json"

module Marketing
  module Esp
    class MailjetWebhookRegistrar
      EVENT_TYPES = %w[sent open click bounce spam blocked unsub].freeze
      API_BASE = "https://api.mailjet.com/v3/REST/eventcallbackurl".freeze
      WEBHOOK_VERSION = 2

      def self.sync!(connection)
        new(connection).sync!
      end

      def self.remove!(connection)
        new(connection).remove!
      end

      def initialize(connection)
        @connection = connection
      end

      def sync!
        return unless connection.connected?

        existing = list_callbacks
        EVENT_TYPES.each do |event_type|
          sync_event_type!(event_type, existing)
        end
      end

      def remove!
        return unless connection.connected?

        list_callbacks.each_value do |callback|
          next unless callback["Url"] == webhook_url

          delete_callback(callback["ID"])
        end
      end

      private

      attr_reader :connection

      def webhook_url
        connection.webhook_url
      end

      def sync_event_type!(event_type, existing)
        callback = existing[event_type]
        return if callback && callback_active?(callback)

        delete_callback(callback["ID"]) if callback
        create_callback(event_type)
      end

      def callback_active?(callback)
        callback["Status"] != "dead" &&
          callback["Version"].to_i == WEBHOOK_VERSION &&
          callback["Url"] == webhook_url
      end

      def list_callbacks
        response = request(:get, API_BASE)
        raise "Mailjet webhook list failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        Array(body["Data"]).index_by { |row| row["EventType"].to_s.downcase }
      end

      def create_callback(event_type)
        response = request(:post, API_BASE, {
          "EventType" => event_type,
          "Url" => webhook_url,
          "Version" => WEBHOOK_VERSION
        })
        return if response.is_a?(Net::HTTPSuccess)

        raise "Mailjet webhook create failed for #{event_type} (#{response.code})"
      end

      def delete_callback(id)
        return if id.blank?

        response = request(:delete, "#{API_BASE}/#{id}")
        return if response.is_a?(Net::HTTPSuccess)

        raise "Mailjet webhook delete failed (#{response.code})"
      end

      def request(method, url, body = nil)
        uri = URI(url)
        request_class = {
          get: Net::HTTP::Get,
          post: Net::HTTP::Post,
          delete: Net::HTTP::Delete
        }.fetch(method)

        request = request_class.new(uri)
        request.basic_auth(connection.api_key, connection.secret_key)
        request["Content-Type"] = "application/json"
        request.body = body.to_json if body

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 15) do |http|
          http.request(request)
        end
      end
    end
  end
end
