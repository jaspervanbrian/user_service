# frozen_string_literal: true

require "test_helper"

class UsersPaginateTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "paginates users with default limit" do
    result = Users::Paginate.call(limit: 2)

    assert_equal 2, result[:users].size
    assert result[:pagination][:has_next_page]
    assert result[:pagination][:next_cursor].present?
    assert_equal 2, result[:pagination][:limit]
  end

  test "traverses pages using next_cursor without duplicate records" do
    # Fetch page 1
    page1 = Users::Paginate.call(limit: 2)
    assert_equal 2, page1[:users].size
    page1_ids = page1[:users].map(&:id)

    # Fetch page 2 using next_cursor
    cursor = page1[:pagination][:next_cursor]
    page2 = Users::Paginate.call(cursor: cursor, limit: 2)
    page2_ids = page2[:users].map(&:id)

    # Ensure no overlap between pages
    assert_empty page1_ids & page2_ids
    assert page2[:users].first.id > page1[:users].last.id
  end

  test "returns has_next_page false and nil cursor on final page" do
    # Request a limit larger than total count
    result = Users::Paginate.call(limit: 50)

    assert_not result[:pagination][:has_next_page]
    assert_nil result[:pagination][:next_cursor]
  end

  test "handles malformed or invalid cursor gracefully" do
    result = Users::Paginate.call(cursor: "not-a-valid-cursor", limit: 2)

    assert_equal 2, result[:users].size
    assert_equal User.order(id: :asc).first.id, result[:users].first.id
  end

  test "caps limit at MAX_LIMIT" do
    result = Users::Paginate.call(limit: 999)
    assert_equal Users::Paginate::MAX_LIMIT, result[:pagination][:limit]
  end

  test "respects custom scope" do
    result = Users::Paginate.call(scope: User.where(role: :admin))

    assert result[:users].all?(&:admin?)
    assert_equal User.admin.count, result[:users].size
  end

  test "caches user IDs in cache" do
    # First call fills cache
    Users::Paginate.call(limit: 2)

    cache_key = "users:cursor_ids:cursor=initial:limit=2"
    assert Rails.cache.exist?(cache_key)

    cached_ids = Rails.cache.read(cache_key)
    assert_kind_of Array, cached_ids
    assert_equal 3, cached_ids.size # limit + 1
  end
end
