require "rails_helper"

load Rails.root.join("db/seeds/email_templates_example.rb")

RSpec.describe EmailTemplatesExample do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  describe ".seed!" do
    it "creates the eight example course templates" do
      expect {
        described_class.seed!(workspace: workspace, user: user)
      }.to change(EmailTemplate, :count).by(8)

      expect(workspace.email_templates.pluck(:key)).to match_array(
        %w[
          primer_contacto reserva_confirmada recordatorio_segundo_pago
          ultimo_recordatorio_pago ultimos_ajustes cierre
          envio_formulario proxima_edicion
        ]
      )
    end

    it "is idempotent" do
      described_class.seed!(workspace: workspace, user: user)

      expect {
        described_class.seed!(workspace: workspace, user: user)
      }.not_to change(EmailTemplate, :count)

      template = workspace.email_templates.find_by!(key: "primer_contacto")
      expect(template.shared).to be(true)
      expect(template.subject).to include("[Nombre del curso]")
    end
  end
end
