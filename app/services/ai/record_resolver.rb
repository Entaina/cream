module Ai
  class RecordResolver
    ROUTE_TYPES = {
      "people" => Person,
      "companies" => Company,
      "deals" => Deal
    }.freeze

    MCP_TYPES = {
      "person" => Person,
      "company" => Company,
      "deal" => Deal
    }.freeze

    def self.find!(workspace, type, id)
      klass = ROUTE_TYPES[type.to_s.downcase] || MCP_TYPES[type.to_s.downcase]
      raise ArgumentError, "Unknown record type: #{type}" unless klass

      workspace.public_send(klass.model_name.plural).find(id)
    end

    def self.route_for(record)
      case record
      when Person then "people"
      when Company then "companies"
      when Deal then "deals"
      else raise ArgumentError, "Unsupported record: #{record.class.name}"
      end
    end

    def self.mcp_type_for(record)
      record.class.name.downcase
    end
  end
end
