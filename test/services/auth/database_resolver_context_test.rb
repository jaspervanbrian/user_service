# frozen_string_literal: true

require "test_helper"

class DatabaseResolverContextTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @user1 = users(:admin)
    @user2 = users(:member)
    @token1 = Auth.issuer.issue(@user1)
    @token2 = Auth.issuer.issue(@user2)
  end

  test "returns nil timestamp when request has no Authorization header" do
    request = ActionDispatch::TestRequest.create
    context = Auth::DatabaseResolverContext.new(request)

    assert_nil context.last_write_timestamp
  end

  test "tracks and retrieves last_write_timestamp for authenticated user" do
    request = ActionDispatch::TestRequest.create({ "HTTP_AUTHORIZATION" => "Bearer #{@token1}" })
    context = Auth::DatabaseResolverContext.new(request)

    assert_nil context.last_write_timestamp

    freeze_time do
      context.update_last_write_timestamp

      cached_time = context.last_write_timestamp
      assert_not_nil cached_time
      assert_equal Time.current.to_i, cached_time.to_i
    end
  end

  test "isolates last_write timestamps between different users" do
    req1 = ActionDispatch::TestRequest.create({ "HTTP_AUTHORIZATION" => "Bearer #{@token1}" })
    req2 = ActionDispatch::TestRequest.create({ "HTTP_AUTHORIZATION" => "Bearer #{@token2}" })

    ctx1 = Auth::DatabaseResolverContext.new(req1)
    ctx2 = Auth::DatabaseResolverContext.new(req2)

    ctx1.update_last_write_timestamp

    assert_not_nil ctx1.last_write_timestamp
    assert_nil ctx2.last_write_timestamp
  end
end
