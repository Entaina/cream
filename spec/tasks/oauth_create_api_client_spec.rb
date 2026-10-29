require "rails_helper"
require "rake"

RSpec.describe "oauth:create_api_client" do
  let(:task) { Rake::Task["oauth:create_api_client"] }
  let(:redirect_uri) { "https://script.google.com/macros/d/test/usercallback" }

  before(:all) do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    load Rails.root.join("lib/tasks/oauth.rake").to_s unless Rake::Task.task_defined?("oauth:create_api_client")
  end

  after { task.reenable }

  it "creates a public client with the api scope and prints its client_id" do
    expect {
      expect { task.invoke("CReaM Gmail add-on", redirect_uri) }.to output(/client_id: \S+/).to_stdout
    }.to change(Doorkeeper::Application, :count).by(1)

    application = Doorkeeper::Application.order(:id).last
    expect(application).to have_attributes(name: "CReaM Gmail add-on", redirect_uri: redirect_uri, confidential: false)
    expect(application.scopes.to_a).to eq(["api"])
  end

  it "refuses to run without a redirect URI" do
    expect {
      expect { task.invoke("CReaM Gmail add-on") }.to raise_error(SystemExit).and output(/Usage/).to_stderr
    }.not_to change(Doorkeeper::Application, :count)
  end

  it "rejects a redirect URI Doorkeeper does not accept" do
    expect {
      expect { task.invoke("Bad", "http://example.com/callback") }.to raise_error(SystemExit).and output.to_stderr
    }.not_to change(Doorkeeper::Application, :count)
  end
end
