module Marketing
  class PreferenceToken
    PURPOSE = "marketing_preference".freeze

    def self.generate(person:)
      payload = {"person_id" => person.id, "workspace_id" => person.workspace_id, "email" => person.email}
      verifier.generate(payload)
    end

    def self.verify(token)
      data = verifier.verify(token.to_s)
      person = Person.find_by(id: data["person_id"], workspace_id: data["workspace_id"])
      raise ActiveSupport::MessageVerifier::InvalidSignature unless person
      raise ActiveSupport::MessageVerifier::InvalidSignature unless person.email.to_s.downcase == data["email"].to_s.downcase

      person
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def self.verifier
      Rails.application.message_verifier(PURPOSE)
    end
    private_class_method :verifier
  end
end
