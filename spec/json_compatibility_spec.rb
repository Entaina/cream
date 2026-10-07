require "rails_helper"

RSpec.describe "json 3 compatibility" do
  it "decodes objects with ActiveSupport::JSON.decode" do
    decoded = ActiveSupport::JSON.decode('{"team":"rails","players":36,"active":true,"note":null}')

    expect(decoded).to eq("team" => "rails", "players" => 36, "active" => true, "note" => nil)
  end

  it "forwards keyword options from ActiveSupport::JSON.decode" do
    decoded = ActiveSupport::JSON.decode('{"team":"rails"}', symbolize_names: true)

    expect(decoded).to eq(team: "rails")
  end

  it "round-trips hashes through JSON.generate and JSON.parse" do
    payload = {
      "error" => "not_found",
      "message" => "Missing record",
      "items" => [{"id" => 1, "name" => "Acme"}],
      "meta" => nil
    }

    expect(JSON.parse(JSON.generate(payload))).to eq(payload)
  end

  it "parses JSON produced by Hash#to_json" do
    payload = {Events: [{event: "sent", email: "ada@example.com"}]}

    expect(JSON.parse(payload.to_json)).to eq("Events" => [{"event" => "sent", "email" => "ada@example.com"}])
  end

  it "parses fenced model output through Ai::JsonParser" do
    text = "```json\n{\"summary\":\"Active contact\"}\n```"

    expect(Ai::JsonParser.parse(text)).to eq("summary" => "Active contact")
  end

  it "raises the ActiveSupport parse error on invalid JSON" do
    expect { ActiveSupport::JSON.decode("{") }.to raise_error(ActiveSupport::JSON.parse_error)
  end
end
