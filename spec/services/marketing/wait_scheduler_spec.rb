require "rails_helper"

RSpec.describe Marketing::WaitScheduler do
  let(:zone) { "Europe/Madrid" }
  let(:madrid) { ActiveSupport::TimeZone[zone] }

  def scheduler(config)
    described_class.new(config, zone: zone)
  end

  it "waits the relative minutes when no time is set" do
    from = madrid.local(2026, 9, 16, 10, 0) # Wednesday
    expect(scheduler("minutes" => 90).next_run_at(from: from)).to eq(madrid.local(2026, 9, 16, 11, 30))
  end

  it "defaults to one minute when nothing is configured" do
    from = madrid.local(2026, 9, 16, 10, 0)
    expect(scheduler({}).next_run_at(from: from)).to eq(madrid.local(2026, 9, 16, 10, 1))
  end

  it "holds until the given time later the same day" do
    from = madrid.local(2026, 9, 16, 8, 15)
    expect(scheduler("minutes" => 0, "until_time" => "10:00").next_run_at(from: from))
      .to eq(madrid.local(2026, 9, 16, 10, 0))
  end

  it "releases immediately when it is exactly the given time" do
    from = madrid.local(2026, 9, 16, 10, 0)
    expect(scheduler("until_time" => "10:00").next_run_at(from: from))
      .to eq(madrid.local(2026, 9, 16, 10, 0))
  end

  it "holds until the given time the next day when already past" do
    from = madrid.local(2026, 9, 16, 10, 1)
    expect(scheduler("until_time" => "10:00").next_run_at(from: from))
      .to eq(madrid.local(2026, 9, 17, 10, 0))
  end

  it "applies the delay first, then aligns to the time" do
    from = madrid.local(2026, 9, 16, 15, 0)
    expect(scheduler("minutes" => 1440, "until_time" => "10:00").next_run_at(from: from))
      .to eq(madrid.local(2026, 9, 18, 10, 0))
  end

  it "moves weekend results to Monday at the same time" do
    from = madrid.local(2026, 9, 18, 17, 0) # Friday
    expect(scheduler("minutes" => 1440, "until_time" => "10:00", "weekdays_only" => "1").next_run_at(from: from))
      .to eq(madrid.local(2026, 9, 21, 10, 0))
  end

  it "keeps weekday results untouched with weekdays_only" do
    from = madrid.local(2026, 9, 16, 10, 0)
    expect(scheduler("minutes" => 60, "weekdays_only" => "1").next_run_at(from: from))
      .to eq(madrid.local(2026, 9, 16, 11, 0))
  end

  it "evaluates the time in the workspace zone, not UTC" do
    from = Time.find_zone("UTC").local(2026, 9, 16, 22, 30) # 00:30 on the 17th in Madrid
    expect(scheduler("until_time" => "09:00").next_run_at(from: from))
      .to eq(madrid.local(2026, 9, 17, 9, 0))
  end

  it "keeps the wall-clock time across a DST change" do
    from = madrid.local(2026, 10, 24, 12, 0) # Saturday before DST ends on Oct 25
    result = scheduler("until_time" => "09:00", "weekdays_only" => "1").next_run_at(from: from)
    expect(result).to eq(madrid.local(2026, 10, 26, 9, 0))
    expect(result.strftime("%H:%M")).to eq("09:00")
  end

  it "ignores malformed times and validates them" do
    expect(scheduler("until_time" => "25:99").until_time).to be_nil
    expect(described_class.valid_until_time?("09:30")).to be(true)
    expect(described_class.valid_until_time?("")).to be(true)
    expect(described_class.valid_until_time?("9:30")).to be(false)
    expect(described_class.valid_until_time?("25:00")).to be(false)
  end
end
