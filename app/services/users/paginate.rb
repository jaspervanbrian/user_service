# frozen_string_literal: true

require "base64"
require "json"

module Users
  # Service object implementing cursor-based keyset pagination with Redis ID caching.
  #
  # Pattern:
  # 1. Decodes opaque Base64 cursor token to find starting ID.
  # 2. Queries limit + 1 IDs, caching the resulting ID array in Redis.
  # 3. Detects has_next_page by checking if result size > limit (eliminates slow COUNT(*) queries).
  # 4. Hydrates ActiveRecord models by ID preserving order.
  # 5. Generates the next opaque Base64 cursor for the client.
  class Paginate
    DEFAULT_LIMIT = 20
    MAX_LIMIT     = 100
    CACHE_TTL     = 5.minutes

    def self.call(cursor: nil, limit: DEFAULT_LIMIT, scope: User.all)
      new(cursor: cursor, limit: limit, scope: scope).call
    end

    def initialize(cursor: nil, limit: DEFAULT_LIMIT, scope: User.all)
      @cursor = cursor
      @limit  = normalize_limit(limit)
      @scope  = scope
    end

    def call
      cursor_id = decode_cursor_id(@cursor)

      # 1. Fetch limit + 1 IDs from Redis/Rails.cache
      cache_key = "users:cursor_ids:cursor=#{cursor_id || 'initial'}:limit=#{@limit}"
      ids = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        query = @scope.order(id: :asc)
        query = query.where("id > ?", cursor_id) if cursor_id.present?
        query.limit(@limit + 1).pluck(:id)
      end

      # 2. Check if there is a next page
      has_next_page = ids.size > @limit
      page_ids = has_next_page ? ids.first(@limit) : ids

      # 3. Hydrate User models preserving order
      users = if page_ids.any?
        user_map = @scope.where(id: page_ids).index_by(&:id)
        page_ids.map { |id| user_map[id] }.compact
      else
        []
      end

      # 4. Generate opaque cursor from the last item
      next_cursor = if has_next_page && users.last.present?
        encode_cursor(id: users.last.id)
      end

      {
        users: users,
        pagination: {
          next_cursor: next_cursor,
          has_next_page: has_next_page,
          limit: @limit
        }
      }
    end

    private

    def normalize_limit(limit)
      val = limit.to_i
      return DEFAULT_LIMIT if val <= 0

      [ val, MAX_LIMIT ].min
    end

    def decode_cursor_id(cursor_str)
      return nil if cursor_str.blank?

      decoded = JSON.parse(Base64.urlsafe_decode64(cursor_str))
      decoded["id"]&.to_i
    rescue ArgumentError, JSON::ParserError
      nil
    end

    def encode_cursor(payload)
      Base64.urlsafe_encode64(payload.to_json, padding: false)
    end
  end
end
