module Auth
  class Claims
    attr_reader :payload, :sub, :role, :iss, :aud, :exp, :iat, :nbf, :jti

    def initialize(payload)
      @payload = payload.respond_to?(:with_indifferent_access) ? payload.with_indifferent_access : payload
      # "sub" (Subject): The identity of the principal (in our case, the user's ID)
      @sub = @payload[:sub]

      # "role": Custom application claim for RBAC (e.g. "member" or "admin")
      @role = @payload[:role]

      # "iss" (Issuer): The server that created and signed this token (e.g. "http://localhost:3000")
      @iss = @payload[:iss]

      # "aud" (Audience): The intended recipient service for this token (e.g. "user_service")
      @aud = @payload[:aud]

      # "exp" (Expiration Time): Unix timestamp after which the token is rejected
      @exp = @payload[:exp]

      # "iat" (Issued At): Unix timestamp when this token was generated
      @iat = @payload[:iat]

      # "nbf" (Not Before): Unix timestamp before which the token must not be accepted
      @nbf = @payload[:nbf]

      # "jti" (JWT ID): Unique UUID for this token instance; used for revocation and replay prevention
      @jti = @payload[:jti]
    end

    def user_id
      sub.presence&.to_i
    end
  end
end
