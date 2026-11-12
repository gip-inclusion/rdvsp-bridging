module Rdvsp
  # RDV-SP rejected a record (422): its errors as attribute => error codes, without the values (usager data)
  class UnprocessableError < Error
    attr_reader :errors

    def initialize(details)
      @errors = if details.is_a?(Hash)
                  details.to_h { |attribute, list| [attribute.to_s, codes(list)] }
                else
                  { "base" => ["invalid"] }
                end
      summary = @errors.map { |attribute, codes| "#{attribute} #{codes.join('/')}" }.join(", ")
      super("RDV-SP rejected the record: #{summary}")
    end

    private

    def codes(list) = Array(list).map { it.is_a?(Hash) ? it["error"].to_s : "invalid" }
  end
end
