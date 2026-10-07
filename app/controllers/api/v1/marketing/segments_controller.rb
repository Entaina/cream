module Api
  module V1
    module Marketing
      class SegmentsController < BaseController
        requires_feature :marketing_segments

        def index
          authorize Segment.new(workspace: current_workspace), :index?
          segments = policy_scope(current_workspace.segments).ordered.limit(list_limit)
          render json: segments.map { |segment| ::Marketing::ApiPresenter.segment_json(segment) }
        end

        def show
          segment = policy_scope(current_workspace.segments).find(params[:id])
          authorize segment

          members = nil
          if ActiveModel::Type::Boolean.new.cast(params[:include_members])
            base = (segment.record_type == "Person") ? current_workspace.people : current_workspace.public_send(segment.record_type.tableize)
            members = segment.resolve(policy_scope(base).includes(:company)).limit(25).to_a
          end

          render json: ::Marketing::ApiPresenter.segment_json(segment, members: members)
        end
      end
    end
  end
end
