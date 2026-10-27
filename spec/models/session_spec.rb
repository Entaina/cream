require "rails_helper"

RSpec.describe Session do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users

  let(:session) { users(:one).sessions.create! }

  it "expires after its lifetime" do
    expect(session.expires_at).to be_within(1.minute).of(Session::LIFETIME.from_now)
    expect(Session.active).to include(session)

    travel Session::LIFETIME + 1.minute do
      expect(Session.active).not_to include(session)
    end
  end

  it "does not treat sessions without expiry as active" do
    session.update_column(:expires_at, nil)

    expect(Session.active).not_to include(session)
  end

  describe "#touch_activity!" do
    it "does not write on every request" do
      original = session.expires_at

      travel 10.minutes do
        session.touch_activity!
        expect(session.reload.expires_at).to eq(original)
      end
    end

    it "renews the expiry once the renewal interval has passed" do
      travel Session::RENEWAL_INTERVAL + 1.minute do
        session.touch_activity!
        expect(session.reload.expires_at).to be_within(1.minute).of(Session::LIFETIME.from_now)
      end
    end
  end
end
