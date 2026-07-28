require "rails_helper"

RSpec.describe Ai::Client, "#chat_with_tools" do
  let(:tools) do
    [ { type: "function", name: "get_weather", description: "Weather",
        parameters: { type: "object", properties: {} } } ]
  end

  def http_double
    @http ||= begin
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      http
    end
  end

  def success(body)
    response = instance_double(Net::HTTPSuccess, body: body.to_json, code: "200")
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    response
  end

  before do
    allow(Ai::Configuration).to receive_messages(configured?: true, api_key: "test-key",
      api_url: "https://api.openai.com/v1/responses", model: "test-model", timeout: 5, temperature: nil)
  end

  it "executes tool calls and feeds results back until the model answers" do
    tool_call = { type: "function_call", call_id: "call_1", name: "get_weather", arguments: '{"city":"Madrid"}' }
    requests = []
    allow(http_double).to receive(:request) do |req|
      requests << JSON.parse(req.body)
      requests.size == 1 ? success(output: [ tool_call ]) : success(output_text: "Sunny in Madrid")
    end

    executed = []
    result = described_class.new.chat_with_tools(system: "sys", input: "weather?", tools: tools) do |name, args|
      executed << [ name, args ]
      "22C sunny"
    end

    expect(result).to eq("Sunny in Madrid")
    expect(executed).to eq([ [ "get_weather", { "city" => "Madrid" } ] ])

    second_input = requests.last["input"]
    expect(second_input).to include(hash_including("type" => "function_call", "call_id" => "call_1"))
    expect(second_input).to include(hash_including("type" => "function_call_output",
      "call_id" => "call_1", "output" => "22C sunny"))
    expect(requests.last["tools"]).to be_present
  end

  it "returns nil when the model ends without a final message" do
    allow(http_double).to receive(:request).and_return(success(output: []))

    result = described_class.new.chat_with_tools(system: "sys", input: "x", tools: tools) { "unused" }

    expect(result).to be_nil
  end

  it "raises when the loop exceeds max_iterations" do
    tool_call = { type: "function_call", call_id: "call_1", name: "get_weather", arguments: "{}" }
    allow(http_double).to receive(:request).and_return(success(output: [ tool_call ]))

    expect {
      described_class.new.chat_with_tools(system: "sys", input: "x", tools: tools, max_iterations: 3) { "ok" }
    }.to raise_error(Ai::Client::Error, /exceeded 3 iterations/)
  end

  it "raises NotConfigured without an API key" do
    allow(Ai::Configuration).to receive(:configured?).and_return(false)

    expect {
      described_class.new.chat_with_tools(system: "s", input: "i", tools: tools) { "x" }
    }.to raise_error(Ai::Client::NotConfigured)
  end
end
