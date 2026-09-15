require "rails_helper"

RSpec.describe SalesBriefing, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  def build_briefing(**attrs)
    workspace.sales_briefings.build({
      briefing_date: Date.current,
      summary: "Resumen",
      items: [],
      wins: [],
      misses: [],
      generated_at: Time.current
    }.merge(attrs))
  end

  it "requires a unique team briefing per workspace and date" do
    build_briefing.save!
    duplicate = build_briefing

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:briefing_date]).to be_present
  end

  it "allows a personal briefing alongside the team briefing for the same date" do
    build_briefing.save!
    personal = build_briefing(user: user, summary: "Para ti", wins: ["Deal ganado"], misses: ["Tarea vencida"])

    expect(personal).to be_valid
    expect(personal.save).to be(true)
  end

  it "requires a unique personal briefing per user and date" do
    build_briefing(user: user, wins: ["Buen cierre"]).save!
    duplicate = build_briefing(user: user, wins: ["Otro acierto"])

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:briefing_date]).to be_present
  end

  it "validates item priorities and text" do
    briefing = build_briefing(items: [{"priority" => "urgent", "text" => "Llamar al cliente"}])

    expect(briefing).to be_valid
    expect(briefing.urgent_items.size).to eq(1)
    expect(briefing.important_items).to be_empty
  end

  it "rejects invalid item priorities" do
    briefing = build_briefing(items: [{"priority" => "critical", "text" => "Hacer algo"}])

    expect(briefing).not_to be_valid
  end

  it "validates wins and misses as string arrays for personal briefings" do
    briefing = build_briefing(user: user, wins: ["Buen trabajo"], misses: ["Retrasaste el follow-up"])

    expect(briefing).to be_valid
  end

  it "requires team briefings to keep wins and misses empty" do
    briefing = build_briefing(wins: ["No permitido"])

    expect(briefing).not_to be_valid
    expect(briefing.errors[:wins]).to be_present
  end

  it "scopes team and personal briefings" do
    team = build_briefing
    team.save!
    personal = build_briefing(user: user, wins: ["Acierto"])
    personal.save!

    expect(workspace.sales_briefings.team).to contain_exactly(team)
    expect(workspace.sales_briefings.personal_for(user)).to contain_exactly(personal)
  end

  it "resolves workspace-scoped records safely" do
    deal = create_deal!(workspace)
    foreign_deal = create_deal!(workspaces(:two))

    briefing = build_briefing(items: [
      {"priority" => "urgent", "text" => "Seguimiento", "record_type" => "Deal", "record_id" => deal.id},
      {"priority" => "important", "text" => "Ignorar", "record_type" => "Deal", "record_id" => foreign_deal.id}
    ])
    briefing.save!

    expect(briefing.record_for(briefing.urgent_items.first)).to eq(deal)
    expect(briefing.record_for(briefing.important_items.first)).to be_nil
  end
end
