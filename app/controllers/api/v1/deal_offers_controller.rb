module Api
  module V1
    class DealOffersController < BaseController
      # Uploads a proposal to a deal. Creates the offer, or adds a new version when it already exists
      # (see Api::DealOfferUploader). Content: pasted `html_body`, a Base64 object
      # (`filename`, `content`, `content_type?`) in a JSON body, or a file upload
      # (multipart/form-data: offer[file]).
      def create
        deal = policy_scope(current_workspace.deals).find(params[:deal_id])
        authorize deal, :update?

        result = Api::DealOfferUploader.new(
          workspace: current_workspace, user: current_user, deal: deal,
          attrs: offer_params.slice(:name, :offer_id, :comment, :html_body), file: raw_file
        ).upload

        if result.saved?
          render json: Api::DealOfferUploader.json(result), status: :created
        else
          render json: {errors: result.errors}, status: :unprocessable_entity
        end
      rescue Api::DealOfferUploader::InvalidOffer, Api::RecordAttachmentBuilder::InvalidAttachment => e
        render json: {errors: [e.message]}, status: :unprocessable_entity
      end

      private

      def offer_params
        params.require(:offer).permit(:name, :offer_id, :comment, :html_body, :file, :filename, :content, :content_type)
      end

      def raw_file
        offer_params[:file].presence || offer_params.slice(:filename, :content, :content_type)
      end
    end
  end
end
