module Marketing
  class EmailContent
    attr_reader :subject, :body, :body_editor, :email_layout, :base_template

    def self.from_campaign(campaign)
      new(
        subject: campaign.email_subject,
        body: campaign.email_body,
        body_editor: campaign.email_body_editor,
        email_layout: campaign.email_layout,
        base_template: campaign.email_template
      )
    end

    def self.from_journey_step(step, workspace:)
      config = step.config.to_h.stringify_keys
      layout = workspace.email_layouts.find_by(id: config["email_layout_id"])
      template = workspace.email_templates.find_by(id: config["email_template_id"])

      new(
        subject: config["subject"],
        body: config["body"],
        body_editor: config["body_editor"].presence || "quill",
        email_layout: layout,
        base_template: template
      )
    end

    def self.from_template(template)
      new(
        subject: template.subject,
        body: template.body,
        body_editor: template.body_editor,
        email_layout: template.email_layout,
        base_template: template
      )
    end

    def initialize(subject:, body:, body_editor: "quill", email_layout: nil, base_template: nil)
      @subject = subject.to_s
      @body = body.to_s
      @body_editor = body_editor.presence || "quill"
      @email_layout = email_layout
      @base_template = base_template
    end

    def present?
      body.present? || base_template.present?
    end

    def effective_body_editor
      return "html" if body_editor == "quill" && EmailTemplate.quill_unsupported_tags(body).any?

      body_editor
    end

    def render_subject_for(record, extra_tokens: {})
      if body.present? || subject.present?
        renderer.render_subject_for(record, extra_tokens: extra_tokens)
      else
        base_template.render_subject_for(record, extra_tokens: extra_tokens)
      end
    end

    def render_for(record, extra_tokens: {})
      if body.present?
        renderer.render_for(record, extra_tokens: extra_tokens)
      else
        base_template.render_for(record, extra_tokens: extra_tokens)
      end
    end

    def render_custom_for(record, subject: nil, body: nil, extra_tokens: {})
      if subject.present? || body.present?
        renderer.render_custom_for(record, subject: subject, body: body, extra_tokens: extra_tokens)
      else
        render_subject = render_subject_for(record, extra_tokens: extra_tokens)
        render_body = render_for(record, extra_tokens: extra_tokens)
        [ render_subject, render_body ]
      end
    end

    def default_body
      body.presence || base_template&.body.to_s
    end

    def default_subject
      subject.presence || base_template&.subject.to_s
    end

    def attach_to(message)
      return unless base_template&.attachments&.attached?

      base_template.attachments.each { |file| message.attachments.attach(file.blob) }
    end

    private

    def renderer
      @renderer ||= EmailTemplate.new(
        subject: subject.presence || base_template&.subject,
        body: body,
        email_layout: email_layout || base_template&.email_layout
      )
    end
  end
end
