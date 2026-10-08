module Api
  # Uploads a proposal (Offer) to a deal for the REST API and MCP. The content is a PDF/HTML/ZIP file
  # (uploaded or Base64) or pasted HTML. If the deal already has the target offer, the content
  # becomes its next numbered version; otherwise a new offer is created with version 1.
  #
  # Target offer: `offer_id`, else the offer whose name matches `name` (case-insensitive), else —
  # when neither is given — the deal's only offer. A name that matches nothing creates a new offer.
  # The caller authorizes the deal (`update?`) before calling `upload`.
  class DealOfferUploader
    InvalidOffer = Class.new(StandardError)

    Result = Data.define(:offer, :version, :offer_created, :errors) do
      def saved? = errors.empty?
    end

    def self.json(result)
      version = result.version
      {
        id: result.offer.id,
        name: result.offer.name,
        offer_created: result.offer_created,
        version: {
          id: version.id,
          number: version.number,
          comment: version.comment,
          content_type: version.file.attached? ? version.file.content_type : "text/html",
          filename: version.file.attached? ? version.file.filename.to_s : nil,
          byte_size: version.file.attached? ? version.file.byte_size : version.html_body.to_s.bytesize,
          created_at: version.created_at.iso8601
        },
        versions_count: result.offer.versions.count
      }
    end

    # attrs: name, offer_id, comment, html_body. file: UploadedFile or {filename, content, content_type?}.
    def initialize(workspace:, user:, deal:, attrs:, file: nil)
      @workspace = workspace
      @user = user
      @deal = deal
      @attrs = attrs.to_h.symbolize_keys
      @file = file
    end

    def upload
      offer = resolve_offer
      created = offer.new_record?
      version = offer.versions.new(user: @user, html_body: @attrs[:html_body].presence, comment: @attrs[:comment].presence)
      attach_file(version) if @file.present?
      offer.name = version.file.filename.base if offer.name.blank? && version.file.attached?

      saved = [offer.valid?, version.valid?].all? && offer.save
      Result.new(offer: offer, version: version, offer_created: created,
        errors: saved ? [] : (offer.errors.full_messages + version.errors.full_messages).uniq)
    end

    private

    def resolve_offer
      return @deal.offers.find(@attrs[:offer_id]) if @attrs[:offer_id].present?

      name = @attrs[:name].to_s.strip
      offers = @deal.offers.order(:id)
      existing = if name.present?
        offers.find_by("LOWER(offers.name) = ?", name.downcase)
      else
        resolve_unnamed(offers)
      end
      existing || @deal.offers.new(workspace: @workspace, user: @user, name: name)
    end

    def resolve_unnamed(offers)
      return nil if offers.none?
      return offers.first if offers.one?

      raise InvalidOffer, "the deal has several offers: pass offer_id or name to choose which one gets the new version"
    end

    def attach_file(version)
      Api::RecordAttachmentBuilder.new(workspace: @workspace, user: @user, record: @deal).attach(version, @file)
    end
  end
end
