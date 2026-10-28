module Api
  class DocsController < ActionController::Base
    layout false

    content_security_policy only: :show do |policy|
      policy.script_src :self, "https://cdn.jsdelivr.net"
      policy.style_src :self, :unsafe_inline, "https://cdn.jsdelivr.net"
    end

    def show
    end

    def openapi
      send_file Rails.root.join("docs/openapi.yaml"),
        type: "application/yaml",
        disposition: "inline"
    end
  end
end
