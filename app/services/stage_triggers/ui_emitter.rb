module StageTriggers
  # Single delivery surface for trigger UI actions, shared by LLM tools and
  # native functions. Every action is recorded on the run for auditing; the
  # broadcast targets the browser of the user who moved the deal. Without a
  # user (MCP/API path) actions are audit-only no-ops.
  class UiEmitter
    TOAST_KINDS = %w[info success warning].freeze
    CONFIRM_FOLLOW_UPS = %w[visit toast].freeze

    def initialize(user:, deal:, run:)
      @user = user
      @deal = deal
      @run = run
    end

    def show_toast(message:, kind: "info")
      kind = TOAST_KINDS.include?(kind.to_s) ? kind.to_s : "info"
      record("show_toast", message: message, kind: kind)
      return unless @user

      Turbo::StreamsChannel.broadcast_append_to(@user, :ui, target: "toasts",
        partial: "shared/toast", locals: { message: message, kind: kind })
    end

    def show_alert(message:, title: nil)
      record("show_alert", message: message, title: title)
      return unless @user

      Turbo::StreamsChannel.broadcast_action_to(@user, :ui, action: "stage_trigger_alert",
        target: "toasts", attributes: { message: message, title: title }.compact)
    end

    def show_confirm(message:, follow_up_type:, follow_up_url: nil, follow_up_message: nil, title: nil)
      unless CONFIRM_FOLLOW_UPS.include?(follow_up_type.to_s)
        raise ArgumentError, "follow_up_type must be one of #{CONFIRM_FOLLOW_UPS.join(", ")}"
      end
      if follow_up_url.present? && !follow_up_url.start_with?("/")
        raise ArgumentError, "follow_up_url must be an internal path starting with /"
      end

      record("show_confirm", message: message, follow_up_type: follow_up_type,
        follow_up_url: follow_up_url, follow_up_message: follow_up_message, title: title)
      return unless @user

      Turbo::StreamsChannel.broadcast_action_to(@user, :ui, action: "stage_trigger_confirm",
        target: "toasts", attributes: {
          message: message, title: title, "follow-up-type": follow_up_type,
          "follow-up-url": follow_up_url, "follow-up-message": follow_up_message
        }.compact)
    end

    def show_deal_panel(markdown:, title: nil)
      record("show_deal_panel", markdown: markdown, title: title)
      @run.update!(panel_title: title, panel_markdown: markdown)
      return unless @user

      Turbo::StreamsChannel.broadcast_update_to(@user, :ui, target: "deal_trigger_panel_#{@deal.id}",
        partial: "deals/trigger_panel", locals: { deal: @deal, run: @run })
    end

    private

    def record(action, **params)
      @run.ui_actions << { "action" => action, "params" => params.compact.stringify_keys, "at" => Time.current.iso8601 }
      @run.save!
    end
  end
end
