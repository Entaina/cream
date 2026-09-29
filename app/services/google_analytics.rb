# frozen_string_literal: true

class GoogleAnalytics
  GA4_ID_FORMAT = /\AG-[A-Z0-9]+\z/i

  def self.measurement_id_for(workspace)
    workspace&.ga_measurement_id.to_s.strip.presence
  end

  def self.enabled?(workspace:)
    measurement_id_for(workspace).present?
  end

  def self.script_tag(workspace:)
    id = measurement_id_for(workspace)
    return "" if id.blank?

    id = ERB::Util.html_escape(id)
    <<~HTML
      <script async src="https://www.googletagmanager.com/gtag/js?id=#{id}"></script>
      <script>
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());
        gtag('config', '#{id}');
      </script>
    HTML
  end
end
