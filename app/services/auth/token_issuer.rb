require "securerandom"

module Auth
  class TokenIssuer
    attr_reader :config, :key_set

    def initialize(config: Auth.config, key_set: Auth.key_set)
      @config = config
      @key_set = key_set
    end

    def issue(user, ttl: config.ttl_seconds)
      now = Time.current.to_i

      payload = {
        sub: user.id.to_s,
        role: user.role,
        iss: config.issuer,
        aud: config.audience,
        iat: now,
        nbf: now,
        exp: now + ttl.to_i,
        jti: SecureRandom.uuid
      }

      headers = {
        alg: "RS256",
        kid: key_set.signing_kid,
        typ: "JWT"
      }

      JWT.encode(payload, key_set.signing_key, "RS256", headers)
    end
  end
end
