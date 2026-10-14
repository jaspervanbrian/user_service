require "test_helper"

class SessionsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin) # AdaAdmin / ada@example.com / password123
    @member = users(:member) # MikeM / mike@example.com / password123
  end

  test "login with username (exact casing)" do
    post api_v1_sessions_url, params: { login: "AdaAdmin", password: "password123" }, as: :json

    assert_response :created
    json = response.parsed_body

    assert json.key?("token")
    assert_equal "Bearer", json["token_type"]
    assert_equal Auth.config.ttl_seconds, json["expires_in"]

    # Verify returned token with Auth.verifier
    claims = Auth.verifier.verify(json["token"])
    assert_equal @admin.id, claims.user_id
    assert_equal "admin", claims.role

    # User payload has private fields (self-view)
    user_payload = json["user"]
    assert_equal @admin.id, user_payload["id"]
    assert_equal @admin.username, user_payload["username"]
    assert_equal @admin.email, user_payload["email"]
    assert_equal @admin.date_of_birth.as_json, user_payload["date_of_birth"]
  end

  test "login with username case-insensitively" do
    post api_v1_sessions_url, params: { login: "adaadmin", password: "password123" }, as: :json

    assert_response :created
    assert response.parsed_body.key?("token")
  end

  test "login with email case-insensitively" do
    post api_v1_sessions_url, params: { login: "ADA@EXAMPLE.COM", password: "password123" }, as: :json

    assert_response :created
    assert response.parsed_body.key?("token")
  end

  test "login supports nested user param structure" do
    post api_v1_sessions_url, params: { user: { login: "MikeM", password: "password123" } }, as: :json

    assert_response :created
    assert response.parsed_body.key?("token")
  end

  test "login fails with wrong password" do
    post api_v1_sessions_url, params: { login: "AdaAdmin", password: "wrongpassword" }, as: :json

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Invalid credentials", json["error"]
  end

  test "login fails with non-existent user" do
    post api_v1_sessions_url, params: { login: "nonexistent", password: "password123" }, as: :json

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Invalid credentials", json["error"]
  end
end
