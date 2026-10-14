module Auth
  module Verifiers
    class Local
      attr_reader :config, :key_set

      def initialize(config: Auth.config, key_set: Auth.key_set)
        @config = config
        @key_set = key_set
      end

      # Accepts an ActionDispatch::Request, rack env hash, or raw token string
      def verify(request_or_token)
        token = extract_token(request_or_token)
        raise Errors::MissingToken if token.blank?

        options = {
          algorithms: [ "RS256" ],
          jwks: key_set.to_jwks,
          iss: config.issuer,
          verify_iss: true,
          aud: config.audience,
          verify_aud: true,
          verify_iat: true
        }

        decoded, _headers = JWT.decode(token, nil, true, options)
        Claims.new(decoded)
      rescue JWT::ExpiredSignature => e
        raise Errors::ExpiredToken, "Token has expired: #{e.message}"
      rescue JWT::DecodeError, JWT::VerificationError => e
        raise Errors::InvalidToken, "Invalid token: #{e.message}"
      end

      private

      def extract_token(target)
        if target.is_a?(String)
          target.sub(/\ABearer\s+/i, "").strip
        elsif target.respond_to?(:headers)
          extract_from_header(target.headers["Authorization"])
        elsif target.is_a?(Hash)
          extract_from_header(target["HTTP_AUTHORIZATION"] || target["Authorization"])
        end
      end

      def extract_from_header(header)
        return nil if header.blank?

        match = header.match(/\ABearer\s+(.+)\z/i)
        match ? match[1].strip : nil
      end
    end
  end
end
