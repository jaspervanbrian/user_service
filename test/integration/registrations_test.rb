# frozen_string_literal: true

require "test_helper"

class RegistrationsTest < ActionDispatch::IntegrationTest
  test "public registration creates member user and returns token" do
    assert_difference("User.count", 1) do
      post api_v1_registrations_url, params: {
        user: {
          first_name: "Katherine",
          last_name: "Johnson",
          username: "kjohnson",
          email: "kjohnson@example.com",
          password: "password123",
          password_confirmation: "password123",
          date_of_birth: "1918-08-26"
        }
      }, as: :json
    end

    assert_response :created
    json = response.parsed_body

    assert json.key?("token")
    assert_equal "Bearer", json["token_type"]
    assert_equal Auth.config.ttl_seconds, json["expires_in"]

    created_user = User.find_by!(username: "kjohnson")
    assert_equal "member", created_user.role

    # Token claims match newly created member
    claims = Auth.verifier.verify(json["token"])
    assert_equal created_user.id, claims.user_id
    assert_equal "member", claims.role

    # Response user object contains self-view fields
    user_payload = json["user"]
    assert_equal created_user.id, user_payload["id"]
    assert_equal "kjohnson", user_payload["username"]
    assert_equal "kjohnson@example.com", user_payload["email"]
    assert_equal "1918-08-26", user_payload["date_of_birth"]
    assert_equal "member", user_payload["role"]
  end

  test "public registration ignores role parameter and strictly enforces member role" do
    assert_difference("User.count", 1) do
      post api_v1_registrations_url, params: {
        first_name: "Hacker",
        last_name: "User",
        username: "hacker123",
        email: "hacker@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: "admin"
      }, as: :json
    end

    assert_response :created
    created_user = User.find_by!(username: "hacker123")
    assert_equal "member", created_user.role
  end

  test "public registration fails with validation errors when invalid" do
    assert_no_difference("User.count") do
      post api_v1_registrations_url, params: {
        user: {
          first_name: "",
          username: "",
          email: "invalid-email",
          password: "short"
        }
      }, as: :json
    end

    assert_response :unprocessable_content
    json = response.parsed_body
    assert json.key?("errors")
  end
end
