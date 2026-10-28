require "rails_helper"

RSpec.describe SafeOutboundHttp do
  def start_with(addresses, url: "https://hooks.example.com/x")
    allow(Resolv).to receive(:getaddresses).and_return(addresses)
    described_class.start(URI.parse(url)) { |http| http }
  end

  it "rejects non-http schemes" do
    expect { described_class.start(URI.parse("ftp://example.com")) { nil } }.to raise_error(ArgumentError, /scheme/)
  end

  it "rejects hosts that do not resolve" do
    expect { start_with([]) }.to raise_error(ArgumentError, /does not resolve/)
  end

  [
    "127.0.0.1", "10.1.2.3", "172.16.0.1", "192.168.1.1", "169.254.169.254", "100.64.0.1",
    "0.0.0.0", "::1", "fe80::1", "fd00::1", "::ffff:127.0.0.1", "::ffff:169.254.169.254"
  ].each do |address|
    it "rejects #{address}" do
      allow(Net::HTTP).to receive(:new)

      expect { start_with([address]) }.to raise_error(ArgumentError, /private address/)
      expect(Net::HTTP).not_to have_received(:new)
    end
  end

  it "rejects the host when any resolved address is private" do
    expect { start_with(["93.184.216.34", "10.0.0.1"]) }.to raise_error(ArgumentError, /private address/)
  end

  it "connects to the validated address of a public host" do
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).with("hooks.example.com", 443).and_return(http)
    allow(http).to receive_messages(:ipaddr= => nil, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil)
    allow(http).to receive(:start).and_yield

    expect(start_with(["93.184.216.34"])).to eq(http)
    expect(http).to have_received(:ipaddr=).with("93.184.216.34")
    expect(http).to have_received(:use_ssl=).with(true)
  end
end
