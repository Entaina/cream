require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  let(:activity) do
    Activity.new(
      action: "offer_viewed",
      metadata: {
        "contact" => "Ana Pérez",
        "offer" => "Propuesta ACME",
        "version" => 2,
        "shared_by" => "Juan López"
      }
    )
  end

  it "renders offer_viewed with shared_by suffix" do
    sentence = helper.activity_sentence(activity)
    expect(sentence).to include("Ana Pérez")
    expect(sentence).to include("Propuesta ACME")
    expect(sentence).to include("Juan López")
  end
end
