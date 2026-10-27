require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  fixtures :users

  let(:user) { users(:one) }
  let(:session) { user.sessions.create! }

  it "connects with an active session" do
    cookies.signed[:session_id] = session.id

    connect "/cable"

    expect(connection.current_user).to eq(user)
  end

  it "rejects an expired session" do
    session.update_column(:expires_at, 1.minute.ago)
    cookies.signed[:session_id] = session.id

    expect { connect "/cable" }.to have_rejected_connection
  end

  it "rejects a connection without session" do
    expect { connect "/cable" }.to have_rejected_connection
  end
end
