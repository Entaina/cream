module Marketing
  class ConditionEvaluator
    OPERATORS = {
      "eq" => "es igual a",
      "neq" => "no es igual a",
      "contains" => "contiene",
      "gt" => "mayor que",
      "gte" => "mayor o igual",
      "lt" => "menor que",
      "lte" => "menor o igual",
      "blank" => "está vacío",
      "present" => "tiene valor"
    }.freeze

    def initialize(condition)
      @field = condition["field"].to_s
      @operator = condition["operator"].to_s
      @compare_value = condition["compare_value"]
    end

    def met_for_person?(person, metadata: {})
      value = extract_value(person, metadata)
      case @operator
      when "blank" then blank?(value)
      when "present" then !blank?(value)
      when "eq" then value.to_s == @compare_value.to_s
      when "neq" then value.to_s != @compare_value.to_s
      when "contains" then value.to_s.downcase.include?(@compare_value.to_s.downcase)
      when "gt" then compare_numeric(value) > @compare_value.to_i
      when "gte" then compare_numeric(value) >= @compare_value.to_i
      when "lt" then compare_numeric(value) < @compare_value.to_i
      when "lte" then compare_numeric(value) <= @compare_value.to_i
      else false
      end
    end

    private

    def extract_value(person, metadata)
      if @field.start_with?("metadata.")
        metadata[@field.delete_prefix("metadata.")]
      elsif @field.start_with?("person.")
        person.public_send(@field.delete_prefix("person."))
      elsif person.respond_to?(@field)
        person.public_send(@field)
      end
    rescue
      nil
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def compare_numeric(value)
      value.to_i
    end
  end
end
