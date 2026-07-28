require "rails_helper"

RSpec.describe Ai::Client do
  def http_double
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    http
  end

  def success(body)
    response = instance_double(Net::HTTPSuccess, body: body.to_json, code: "200")
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    response
  end

  def stub_configuration
    allow(Ai::Configuration).to receive(:configured?).and_return(true)
    allow(Ai::Configuration).to receive(:api_key).and_return("test-key")
    allow(Ai::Configuration).to receive(:api_url).and_return("https://api.openai.com/v1/responses")
    allow(Ai::Configuration).to receive(:model).and_return("test-model")
    allow(Ai::Configuration).to receive(:timeout).and_return(5)
  end

  it "raises NotConfigured when the API key is missing" do
    allow(Ai::Configuration).to receive(:configured?).and_return(false)

    expect {
      described_class.new.chat(system: "sys", user: "hello")
    }.to raise_error(Ai::Client::NotConfigured)
  end

  it "returns assistant content from output_text" do
    stub_configuration
    payload = { output_text: '{"summary":"Hello"}' }
    allow(http_double).to receive(:request).and_return(success(payload))

    result = described_class.new.chat(system: "sys", user: "hello", json: true)

    expect(result).to eq('{"summary":"Hello"}')
  end

  it "falls back to output message items when output_text is absent" do
    stub_configuration
    payload = {
      output: [
        {
          type: "message",
          role: "assistant",
          content: [
            { type: "output_text", text: '{"summary":"From output"}' }
          ]
        }
      ]
    }
    allow(http_double).to receive(:request).and_return(success(payload))

    result = described_class.new.chat(system: "sys", user: "hello", json: true)

    expect(result).to eq('{"summary":"From output"}')
  end

  it "raises when the model refuses the request" do
    stub_configuration
    payload = {
      output: [
        {
          type: "message",
          role: "assistant",
          content: [
            { type: "output_refusal", refusal: "Not allowed" }
          ]
        }
      ]
    }
    allow(http_double).to receive(:request).and_return(success(payload))

    expect {
      described_class.new.chat(system: "sys", user: "hello")
    }.to raise_error(Ai::Client::Error, /refused/)
  end

  it "raises when the provider responds with an error" do
    stub_configuration

    failure = instance_double(Net::HTTPBadRequest, code: "400", body: "bad request")
    allow(failure).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    allow(http_double).to receive(:request).and_return(failure)

    expect {
      described_class.new.chat(system: "sys", user: "hello")
    }.to raise_error(Ai::Client::Error, /LLM request failed/)
  end

  it "omits temperature for models that do not support it" do
    stub_configuration
    allow(Ai::Configuration).to receive(:model).and_return("gpt-5")
    allow(Ai::Configuration).to receive(:temperature).and_return(nil)

    http = http_double
    expect(http).to receive(:request) do |request|
      body = JSON.parse(request.body)
      expect(body).not_to have_key("temperature")
      success({ output_text: "ok" })
    end

    described_class.new.chat(system: "sys", user: "hello")
  end

  it "adds a JSON hint to the user input when json mode is enabled" do
    stub_configuration

    http = http_double
    expect(http).to receive(:request) do |request|
      body = JSON.parse(request.body)
      expect(body["input"]).to include("JSON")
      expect(body.dig("text", "format", "type")).to eq("json_object")
      success({ output_text: '{"summary":"ok"}' })
    end

    described_class.new.chat(system: "sys", user: "Analyze this", json: true)
  end
end
