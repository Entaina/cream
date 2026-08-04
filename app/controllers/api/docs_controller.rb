module Api
  class DocsController < ActionController::Base
    layout false

    def show
    end

    def openapi
      send_file Rails.root.join("docs/openapi.yaml"),
        type: "application/yaml",
        disposition: "inline"
    end
  end
end
