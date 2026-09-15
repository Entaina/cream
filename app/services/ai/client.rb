require "net/http"
require "json"

module Ai
  # OpenAI Responses API client. HTTP is done with Net::HTTP so specs can stub
  # requests without calling real providers.
  class Client
    Error = Class.new(StandardError)
    NotConfigured = Class.new(Error)

    def chat(system:, user:, json: false)
      raise NotConfigured, "CREAM_AI_API_KEY is not set" unless Configuration.configured?

      input = user
      input = "#{user}\n\nRespond in JSON." if json && !user.match?(/json/i)

      payload = {
        model: Configuration.model,
        instructions: system,
        input: input,
        store: false
      }
      payload[:temperature] = Configuration.temperature if Configuration.temperature
      payload[:text] = {format: {type: "json_object"}} if json

      response = post_json(URI(Configuration.api_url), payload)
      raise Error, "LLM request failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      extract_output_text(body)
    end

    # Function-calling loop over the Responses API. `tools` is an array of
    # { type: "function", name:, description:, parameters: <JSON Schema> }.
    # The block executes each tool call and returns its result as a String.
    # Since we use store: false, the whole conversation is resent every turn.
    # Returns the model's final text (nil if it finishes without a message).
    def chat_with_tools(system:, input:, tools:, max_iterations: 8)
      raise NotConfigured, "CREAM_AI_API_KEY is not set" unless Configuration.configured?

      conversation = [{role: "user", content: input}]
      max_iterations.times do
        payload = {model: Configuration.model, instructions: system,
                   input: conversation, tools: tools, store: false}
        payload[:temperature] = Configuration.temperature if Configuration.temperature

        response = post_json(URI(Configuration.api_url), payload)
        raise Error, "LLM request failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        calls = Array(body["output"]).select { |item| item["type"] == "function_call" }
        return final_output_text(body) if calls.empty?

        calls.each do |call|
          conversation << call.slice("type", "call_id", "name", "arguments")
          result = yield(call["name"], JSON.parse(call["arguments"].presence || "{}"))
          conversation << {type: "function_call_output", call_id: call["call_id"], output: result.to_s}
        end
      end
      raise Error, "Tool loop exceeded #{max_iterations} iterations"
    end

    private

    # Like extract_output_text but tolerates an empty final message.
    def final_output_text(body)
      extract_output_text(body)
    rescue Error => e
      raise unless e.message == "Empty LLM response"

      nil
    end

    def extract_output_text(body)
      text = body["output_text"]
      return text if text.present?

      Array(body["output"]).each do |item|
        next unless item["type"] == "message"

        Array(item["content"]).each do |part|
          if part["type"] == "output_refusal"
            raise Error, "LLM refused the request: #{part["refusal"]}"
          end

          return part["text"] if part["type"] == "output_text" && part["text"].present?
        end
      end

      raise Error, "Empty LLM response"
    end

    def post_json(uri, payload)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{Configuration.api_key}"
      request["Content-Type"] = "application/json"
      request.body = payload.to_json

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: Configuration.timeout,
        read_timeout: Configuration.timeout) do |http|
        http.request(request)
      end
    end
  end
end
