module Api
  module V1
    module Marketing
      class CampaignSendsController < BaseController
        requires_feature :marketing_campaigns

        def create
          campaign = policy_scope(current_workspace.campaigns).find(params[:campaign_id])
          authorize campaign, :send_campaign?

          segment = policy_scope(current_workspace.segments).find(send_params[:segment_id])
          unless segment.record_type == "Person"
            return render json: { error: "Segment must be of type Person" }, status: :unprocessable_entity
          end

          unless campaign.email_content_present?
            return render json: { error: "Campaign has no email content configured" }, status: :unprocessable_entity
          end

          template = resolve_campaign_send_template(campaign, send_params[:email_template_id])
          subscription_type = ::Marketing::ApiPresenter.resolve_subscription_type(
            current_workspace,
            send_params[:subscription_type_id]
          )
          scheduled_at = ::Marketing::ApiPresenter.parse_scheduled_at(send_params[:scheduled_at])

          send_record = current_workspace.campaign_sends.create!(
            campaign: campaign,
            segment: segment,
            email_template: template,
            user: current_user,
            subscription_type: subscription_type,
            status: "pending",
            scheduled_at: scheduled_at
          )

          if scheduled_at.present? && scheduled_at > Time.current
            send_record.mark_scheduled!
            campaign.update!(status: "scheduled")
            CampaignSendJob.set(wait_until: scheduled_at).perform_later(send_record.id)
          else
            CampaignSendJob.perform_later(send_record.id)
          end

          render json: {
            campaign_send: ::Marketing::ApiPresenter.campaign_send_json(send_record),
            queued: true
          }, status: :created
        end

        def cancel
          campaign = policy_scope(current_workspace.campaigns).find(params[:campaign_id])
          authorize campaign, :update?
          send_record = campaign.campaign_sends.find(params[:id])
          send_record.cancel!
          render json: {
            campaign_send: ::Marketing::ApiPresenter.campaign_send_json(send_record.reload),
            cancelled: true
          }
        end

        private

        def send_params
          params.require(:campaign_send).permit(:segment_id, :email_template_id, :subscription_type_id, :scheduled_at)
        end

        def resolve_campaign_send_template(campaign, template_id)
          if template_id.present?
            policy_scope(current_workspace.email_templates).find(template_id)
          else
            campaign.email_template
          end
        end
      end
    end
  end
end
