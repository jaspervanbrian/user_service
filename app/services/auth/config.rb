require "openssl"

module Auth
  class Config
    attr_reader :explicit_kid, :issuer, :audience, :ttl_seconds, :private_key_pem, :previous_keys_pem, :verifier_type

    def initialize(
      kid: ENV["JWT_KID"] || credential(:kid),
      issuer: ENV["JWT_ISSUER"] || credential(:issuer) || AuthConstants::DEFAULT_ISSUER,
      private_key_pem: ENV["JWT_PRIVATE_KEY"] || credential(:private_key),
      previous_keys_pem: ENV["JWT_PREVIOUS_KEYS"] || credential(:previous_keys),
      audience: ENV.fetch("JWT_AUDIENCE", credential(:audience) || AuthConstants::DEFAULT_AUDIENCE),
      ttl_seconds: (ENV["JWT_TTL_SECONDS"] || credential(:ttl_seconds) || AuthConstants::DEFAULT_TTL).to_i,
      verifier_type: ENV.fetch("AUTH_VERIFIER", credential(:verifier_type) || AuthConstants::DEFAULT_VERIFIER)
    )
      @explicit_kid = kid.presence
      @issuer = issuer
      @private_key_pem = normalize_pem(private_key_pem)
      @previous_keys_pem = normalize_pem_list(previous_keys_pem)
      @audience = audience
      @ttl_seconds = ttl_seconds
      @verifier_type = verifier_type

      apply_test_defaults! if Rails.env.test? && @private_key_pem.blank?
      validate! unless Rails.env.test? && @private_key_pem.blank?
    end

    def private_key
      @private_key ||= OpenSSL::PKey::RSA.new(private_key_pem)
    rescue OpenSSL::PKey::RSAError => e
      raise Errors::ConfigurationError, "Invalid RSA private key PEM: #{e.message}"
    end

    def previous_keys
      @previous_keys ||= previous_keys_pem.map do |pem|
        OpenSSL::PKey::RSA.new(pem)
      rescue OpenSSL::PKey::RSAError => e
        raise Errors::ConfigurationError, "Invalid previous RSA key PEM: #{e.message}"
      end
    end

    def kid
      # Deterministic KID derived from the key's thumbprint unless an explicit kid was given
      @kid ||= explicit_kid || JWT::JWK.new(private_key).kid
    end

    private

    def credential(key)
      return nil unless defined?(Rails.application.credentials) && Rails.application.credentials.present?

      Rails.application.credentials.dig(:jwt, key) || Rails.application.credentials.public_send(key)
    rescue StandardError
      nil
    end

    def normalize_pem(pem)
      return if pem.blank?

      pem.to_s.gsub('\n', "\n").strip
    end

    def normalize_pem_list(raw)
      return [] if raw.blank?

      if raw.is_a?(Array)
        raw.map { |p| normalize_pem(p) }.compact
      elsif raw.is_a?(String)
        parsed = JSON.parse(raw) rescue nil
        if parsed.is_a?(Array)
          parsed.map { |p| normalize_pem(p) }.compact
        else
          [ normalize_pem(raw) ]
        end
      else
        []
      end
    end

    def apply_test_defaults!
      @test_rsa ||= OpenSSL::PKey::RSA.generate(2048)
      @private_key_pem = @test_rsa.to_pem
      @private_key = @test_rsa
      @issuer ||= AuthConstants::DEFAULT_ISSUER
    end

    def validate!
      missing = []
      missing << "JWT_ISSUER or credentials.issuer" if issuer.blank?
      missing << "JWT_PRIVATE_KEY or credentials.private_key" if private_key_pem.blank?

      if missing.any?
        raise Errors::ConfigurationError, "Missing required Auth configuration: #{missing.join(', ')}"
      end

      # Validate key parseability
      private_key
      previous_keys
    end
  end
end
