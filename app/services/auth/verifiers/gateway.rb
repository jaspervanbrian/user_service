module Auth
  module Verifiers
    # Seam for API Gateway integration.
    # When deployed behind AWS API Gateway HTTP API (or Kong/Apigee) with a JWT Authorizer,
    # the gateway verifies the token at the edge against /.well-known/jwks.json and forwards
    # verified claims to downstream microservices in trusted HTTP headers.
    class Gateway
      CLAIM_HEADER_SUB = "X-User-Id"
      CLAIM_HEADER_ROLE = "X-User-Role"

      def verify(request)
        headers = request.respond_to?(:headers) ? request.headers : request

        sub = headers[CLAIM_HEADER_SUB].presence
        role = headers[CLAIM_HEADER_ROLE].presence

        if sub.blank?
          raise Errors::InvalidToken, "Missing gateway verified identity header (#{CLAIM_HEADER_SUB})"
        end

        Claims.new({ sub: sub, role: role })
      end
    end
  end
end
