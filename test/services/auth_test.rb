require "test_helper"

class AuthTest < ActiveSupport::TestCase
  setup do
    Auth.reset!
    @user = users(:admin)
  end

  teardown do
    Auth.reset!
  end

  test "issues and verifies an RS256 token" do
    token = Auth.issuer.issue(@user)
    assert token.present?

    claims = Auth.verifier.verify(token)
    assert_equal @user.id.to_s, claims.sub
    assert_equal @user.id, claims.user_id
    assert_equal @user.role, claims.role
    assert_equal Auth.config.issuer, claims.iss
    assert_equal Auth.config.audience, claims.aud
    assert claims.jti.present?
  end

  test "token headers contain RS256 and deterministic kid" do
    token = Auth.issuer.issue(@user)
    _payload, headers = JWT.decode(token, nil, false)

    assert_equal "RS256", headers["alg"]
    assert_equal Auth.key_set.signing_kid, headers["kid"]
  end

  test "token contains no PII" do
    token = Auth.issuer.issue(@user)
    payload, _headers = JWT.decode(token, nil, false)

    assert_not payload.key?("email")
    assert_not payload.key?("date_of_birth")
    assert_not payload.key?("first_name")
    assert_not payload.key?("last_name")
  end

  test "rejects expired token" do
    # Issue a token with 0 TTL (expires immediately)
    token = Auth.issuer.issue(@user, ttl: -1)

    assert_raises(Auth::Errors::ExpiredToken) do
      Auth.verifier.verify(token)
    end
  end

  test "rejects tampered token signature" do
    token = Auth.issuer.issue(@user)
    tampered = token + "xyz"

    assert_raises(Auth::Errors::InvalidToken) do
      Auth.verifier.verify(tampered)
    end
  end

  test "rejects missing token" do
    assert_raises(Auth::Errors::MissingToken) do
      Auth.verifier.verify("")
    end

    assert_raises(Auth::Errors::MissingToken) do
      Auth.verifier.verify(nil)
    end
  end

  test "verifies older token during key rotation" do
    old_rsa = OpenSSL::PKey::RSA.generate(2048)
    old_jwk = JWT::JWK.new(old_rsa)

    # Encode token with old key
    now = Time.current.to_i
    old_payload = {
      sub: @user.id.to_s,
      role: @user.role,
      iss: Auth.config.issuer,
      aud: Auth.config.audience,
      iat: now,
      nbf: now,
      exp: now + 300,
      jti: SecureRandom.uuid
    }
    old_token = JWT.encode(old_payload, old_rsa, "RS256", { alg: "RS256", kid: old_jwk.kid })

    # Configure Auth with current active key and old key in previous_keys
    config = Auth::Config.new(
      previous_keys_pem: [ old_rsa.to_pem ]
    )
    key_set = Auth::KeySet.new(config: config)
    verifier = Auth::Verifiers::Local.new(config: config, key_set: key_set)

    # Verifier successfully verifies token signed by old key
    claims = verifier.verify(old_token)
    assert_equal @user.id.to_s, claims.sub
  end

  test "JWKS export contains only public key parameters" do
    jwks = Auth.key_set.to_jwks
    assert jwks.key?(:keys)
    assert_equal 1, jwks[:keys].size

    key = jwks[:keys].first
    assert_equal "RSA", key[:kty]
    assert key.key?(:n)
    assert key.key?(:e)
    assert key.key?(:kid)

    # Crucial security assertion: private components must never be in JWKS
    assert_nil key[:d], "Private exponent 'd' must not be exposed"
    assert_nil key[:p], "Private prime 'p' must not be exposed"
    assert_nil key[:q], "Private prime 'q' must not be exposed"
  end

  test "error classes have default messages and accept custom messages" do
    assert_equal "Authentication error", Auth::Errors::Error.new.message
    assert_equal "Invalid authentication configuration", Auth::Errors::ConfigurationError.new.message
    assert_equal "Invalid authentication token", Auth::Errors::InvalidToken.new.message
    assert_equal "Authentication token has expired", Auth::Errors::ExpiredToken.new.message
    assert_equal "Missing authentication token", Auth::Errors::MissingToken.new.message

    assert_equal "Custom err", Auth::Errors::Error.new("Custom err").message
    assert_equal "Custom exp", Auth::Errors::ExpiredToken.new("Custom exp").message
  end
end
