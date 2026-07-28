# frozen_string_literal: true

# Pagy initializer file (43.5.6)
# See https://ddnexus.github.io/pagy/toolbox/configuration/initializer/

require "pagy"
require "pagy/toolbox/paginators/method"

Pagy::OPTIONS[:limit] = 50
# Preserve v9 overflow: :last_page behavior via ApplicationController#pagy_redirect_to_last_page.
Pagy::OPTIONS[:raise_range_error] = true

Pagy::OPTIONS.freeze
