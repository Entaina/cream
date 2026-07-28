# PaperTrail stores snapshots as JSON to avoid Psych safe_load issues with
# ActiveSupport::TimeWithZone in YAML (Rails 8 + Psych 5).
PaperTrail.config.serializer = PaperTrail::Serializers::JSON
