require "rails_helper"

RSpec.describe StripeClient do
  subject(:client) { described_class.new(api_key: "rk_test_123") }

  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  def success(body)
    response = instance_double(Net::HTTPSuccess, body: body.to_json)
    allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }
    response
  end

  def failure(klass, code, body = {error: {message: "nope"}})
    response = instance_double(klass, code: code.to_s, body: body.to_json)
    allow(response).to receive(:is_a?) { |k| klass <= k }
    response
  end

  describe "#list_charges" do
    it "yields succeeded charges oldest-first and paginates with starting_after" do
      page1 = success({data: [{"id" => "ch_2", "created" => 200}, {"id" => "ch_1", "created" => 100}],
                        has_more: true})
      page2 = success({data: [{"id" => "ch_0", "created" => 50}], has_more: false})
      requests = []
      allow(http).to receive(:request) { |req|
        requests << req.uri.to_s
        (requests.size == 1) ? page1 : page2
      }

      yielded = []
      client.list_charges(created_after: 42) { |charge| yielded << charge["id"] }

      expect(yielded).to eq(%w[ch_1 ch_2 ch_0])
      expect(requests.first).to include("created%5Bgt%5D=42")
      expect(requests.first).to include("expand%5B%5D=data.customer")
      expect(requests.second).to include("starting_after=ch_1")
    end

    it "sends the bearer token" do
      allow(http).to receive(:request) do |req|
        expect(req["Authorization"]).to eq("Bearer rk_test_123")
        success({data: [], has_more: false})
      end

      client.list_charges { |_c| }
    end

    it "raises AuthenticationError on 401" do
      allow(http).to receive(:request).and_return(failure(Net::HTTPUnauthorized, 401))

      expect { client.list_charges { |_c| } }.to raise_error(StripeClient::AuthenticationError)
    end

    it "raises Error with the Stripe message on other failures" do
      allow(http).to receive(:request).and_return(failure(Net::HTTPBadRequest, 400))

      expect { client.list_charges { |_c| } }.to raise_error(StripeClient::Error, /nope/)
    end
  end

  describe "#verify!" do
    it "returns true when the key is accepted" do
      allow(http).to receive(:request).and_return(success({data: []}))

      expect(client.verify!).to be(true)
    end
  end

  describe "#get_charge" do
    it "fetches a single charge with the customer expanded" do
      allow(http).to receive(:request) do |req|
        expect(req.uri.to_s).to include("/charges/ch_1")
        expect(req.uri.to_s).to include("expand%5B%5D=customer")
        success({"id" => "ch_1"})
      end

      expect(client.get_charge("ch_1")).to eq({"id" => "ch_1"})
    end
  end
end
