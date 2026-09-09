require "net/http"
require "json"

module Marketing
  module Beehiiv
    class Client
      BASE_URL = "https://api.beehiiv.com/v2".freeze
      MAX_RETRIES = 3

      class Error < StandardError; end
      class AuthenticationError < Error; end
      class RateLimitError < Error; end

      def initialize(connection)
        @connection = connection
      end

      def list_subscriptions(cursor: nil, limit: 100, status: "all", email: nil, expand: [])
        params = { limit: limit, status: status }
        params[:cursor] = cursor if cursor.present?
        params[:email] = email if email.present?
        params["expand[]"] = expand if expand.any?

        get("/publications/#{@connection.publication_id}/subscriptions", params)
      end

      def find_subscription_by_email(email)
        response = list_subscriptions(email: email, limit: 1, expand: [ "custom_fields" ])
        response.fetch("data", []).first
      end

      def create_subscription(email:, reactivate_existing: false, **options)
        body = {
          email: email,
          reactivate_existing: reactivate_existing,
          send_welcome_email: false,
          double_opt_override: "off",
          utm_source: "cream"
        }.merge(options.compact)

        post("/publications/#{@connection.publication_id}/subscriptions", body)
      end

      def unsubscribe(subscription_id:)
        put(
          "/publications/#{@connection.publication_id}/subscriptions/#{subscription_id}",
          { unsubscribe: true }
        )
      end

      private

      def get(path, params = {})
        request(:get, path, params: params)
      end

      def post(path, body)
        request(:post, path, body: body)
      end

      def put(path, body)
        request(:put, path, body: body)
      end

      def request(method, path, params: nil, body: nil)
        attempts = 0
        begin
          attempts += 1
          uri = URI("#{BASE_URL}#{path}")
          uri.query = URI.encode_www_form(params) if params.present?

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.open_timeout = 10
          http.read_timeout = 30

          request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put }.fetch(method)
          request = request_class.new(uri)
          request["Authorization"] = "Bearer #{@connection.api_key}"
          request["Content-Type"] = "application/json"
          request.body = body.to_json if body

          response = http.request(request)
          handle_response(response)
        rescue RateLimitError
          raise if attempts >= MAX_RETRIES

          sleep(attempts * 2)
          retry
        end
      end

      def handle_response(response)
        if response.is_a?(Net::HTTPSuccess)
          body = response.body.presence
          body.present? ? JSON.parse(body) : {}
        elsif response.is_a?(Net::HTTPUnauthorized)
          raise AuthenticationError, "Beehiiv rejected the API key"
        elsif response.is_a?(Net::HTTPTooManyRequests)
          raise RateLimitError, "Beehiiv rate limit exceeded"
        else
          raise Error, "Beehiiv API error #{response.code}: #{response.body}"
        end
      end
    end
  end
end
