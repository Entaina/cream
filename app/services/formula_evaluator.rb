class FormulaEvaluator
  SAFE_EXPRESSION = %r{\A[\d\s+\-*/().]+\z}

  def self.evaluate(expression, record:)
    return nil if expression.blank?

    substituted = expression.gsub(/\{([\w.]+)\}/) do
      value_for(record, Regexp.last_match(1)).to_s
    end

    # Safe arithmetic only: digits, operators, parentheses, dots, spaces
    return nil unless substituted.match?(SAFE_EXPRESSION)

    result = SafeArithmetic.new(substituted).result
    (result.is_a?(Numeric) && result.finite?) ? result : nil
  rescue SafeArithmetic::Error, ZeroDivisionError
    nil
  end

  def self.value_for(record, token)
    if token.start_with?("cf.")
      record.custom_fields_hash[token.delete_prefix("cf.")]
    elsif record.respond_to?(token)
      record.public_send(token)
    end
  end

  # Minimal recursive-descent evaluator for + - * / and parentheses over decimal
  # numbers. Replaces Kernel#eval to remove the code-execution and
  # exponentiation-based DoS risk (e.g. "9**9**9**9") that eval allowed.
  class SafeArithmetic
    Error = Class.new(StandardError)

    def initialize(input)
      @tokens = tokenize(input)
      @pos = 0
    end

    def result
      value = expression
      raise Error, "unexpected trailing token" unless @pos == @tokens.length

      value
    end

    private

    def tokenize(input)
      input.scan(%r{\d+(?:\.\d+)?|[+\-*/()]}).map do |tok|
        tok.match?(/\A\d/) ? tok.to_f : tok
      end
    end

    def peek = @tokens[@pos]

    def consume
      tok = @tokens[@pos]
      @pos += 1
      tok
    end

    def expression
      value = term
      while peek == "+" || peek == "-"
        op = consume
        value = (op == "+") ? value + term : value - term
      end
      value
    end

    def term
      value = factor
      while peek == "*" || peek == "/"
        op = consume
        value = (op == "*") ? value * factor : value / factor
      end
      value
    end

    def factor
      case (tok = peek)
      when "+" then consume
                    factor
      when "-" then consume
                    -factor
      when "("
        consume
        value = expression
        raise Error, "missing closing parenthesis" unless consume == ")"

        value
      when Float then consume
      else raise Error, "unexpected token: #{tok.inspect}"
      end
    end
  end
end
