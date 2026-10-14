module Auth
  class KeySet
    attr_reader :config

    def initialize(config: Auth.config)
      @config = config
    end

    def active_jwk
      @active_jwk ||= JWT::JWK.new(config.private_key, kid: config.explicit_kid)
    end

    def signing_key
      active_jwk.keypair
    end

    def signing_kid
      active_jwk.kid
    end

    def previous_jwks
      @previous_jwks ||= config.previous_keys.map { |k| JWT::JWK.new(k) }
    end

    def all_jwks
      [ active_jwk, *previous_jwks ]
    end

    # Returns the JWKS payload suitable for GET /.well-known/jwks.json
    def to_jwks
      {
        keys: all_jwks.map(&:export)
      }
    end
  end
end
