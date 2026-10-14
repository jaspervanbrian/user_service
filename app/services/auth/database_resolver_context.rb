# frozen_string_literal: true

module Auth
  # Custom context resolver for Rails automatic database role switching (Primary vs Replica).
  #
  # Why this is needed:
  # Standard Rails DatabaseSelector::Resolver::Session stores the last write timestamp
  # in `request.session` (cookies). In an API-only architecture using stateless JWTs,
  # session cookies do not exist.
  #
  # This resolver keys the user's last write timestamp in Redis/Rails.cache using their JWT user_id.
  #
  # Behavior:
  # - After a write (POST/PATCH/DELETE), updates Redis with Time.current for that user.
  # - On a subsequent read (GET), checks if Time.current - last_write < delay (e.g. 2s).
  # - If within delay -> routes to PRIMARY (prevents Read-Your-Own-Writes lag).
  # - If not in Redis or delay passed -> routes to REPLICA (offloading 99%+ of reads).
  class DatabaseResolverContext
    CACHE_PREFIX = "db_selector:last_write:user"
    TTL          = 10.seconds

    def initialize(request)
      @request = request
    end

    def save(response)
      # Optional hook called by DatabaseSelector middleware after response is generated
    end

    def last_write_timestamp
      uid = user_id
      return nil if uid.blank?

      val = Rails.cache.read(cache_key(uid))
      val.present? ? Time.zone.at(val.to_f) : nil
    end

    def update_last_write_timestamp
      uid = user_id
      return if uid.blank?

      Rails.cache.write(cache_key(uid), Time.current.to_f, expires_in: TTL)
    end

    private

    def user_id
      token = extract_bearer_token
      return nil if token.blank?

      claims = begin
        Auth.verifier.verify(token)
      rescue StandardError
        nil
      end

      claims&.user_id
    end

    def extract_bearer_token
      header = @request.headers["Authorization"] || @request.get_header("HTTP_AUTHORIZATION")
      return nil if header.blank?

      match = header.match(/\ABearer\s+(.+)\z/i)
      match ? match[1].strip : nil
    end

    def cache_key(uid)
      "#{CACHE_PREFIX}:#{uid}"
    end
  end
end
