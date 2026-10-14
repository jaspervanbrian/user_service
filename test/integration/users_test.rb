require "test_helper"

class UsersTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @admin = users(:admin)
    @member = users(:member)
    @other = users(:member_without_dob)
  end

  def auth(user)
    { "Authorization" => "Bearer #{Auth.issuer.issue(user)}" }
  end

  def new_user_params(overrides = {})
    {
      user: {
        first_name: "Nina", last_name: "New", username: "nina_n", email: "nina@example.com",
        password: "password123", password_confirmation: "password123"
      }.merge(overrides)
    }
  end

  # --- index ---

  test "index requires authentication" do
    get "/api/v1/users"
    assert_response :unauthorized
  end

  test "admin sees private fields for everyone" do
    get "/api/v1/users", headers: auth(@admin)
    assert_response :success
    users = response.parsed_body["users"]
    assert_equal User.count, users.size
    assert(users.all? { |u| u.key?("email") })
    assert(users.none? { |u| u.key?("password_digest") })
  end

  test "member sees private fields only for self" do
    get "/api/v1/users", headers: auth(@member)
    assert_response :success
    users = response.parsed_body["users"]
    mine, others = users.partition { |u| u["id"] == @member.id }
    assert_equal "mike@example.com", mine.first["email"]
    assert(others.none? { |u| u.key?("email") || u.key?("date_of_birth") })
  end

  test "index paginates with cursor" do
    get "/api/v1/users", params: { limit: 2 }, headers: auth(@admin)
    body = response.parsed_body
    assert_equal 2, body["users"].size
    assert body["pagination"]["has_next_page"]

    get "/api/v1/users", params: { limit: 2, cursor: body["pagination"]["next_cursor"] }, headers: auth(@admin)
    body2 = response.parsed_body
    assert_equal 1, body2["users"].size
    assert_not body2["pagination"]["has_next_page"]
    assert_empty body["users"].map { |u| u["id"] } & body2["users"].map { |u| u["id"] }
  end

  test "index supports jumping to page number" do
    get "/api/v1/users", params: { limit: 1, page: 2 }, headers: auth(@admin)
    assert_response :success
    body = response.parsed_body
    assert_equal 1, body["users"].size
    assert_equal 2, body["pagination"]["page"]
    assert body["pagination"]["has_next_page"]
    assert body["pagination"]["next_cursor"].present?
  end

  test "index filters users by username query case-insensitively" do
    get "/api/v1/users", params: { query: "ada" }, headers: auth(@admin)
    assert_response :success
    body = response.parsed_body
    assert_equal 1, body["users"].size
    assert_equal "AdaAdmin", body["users"].first["username"]

    get "/api/v1/users", params: { query: "nonexistent_username_xyz" }, headers: auth(@admin)
    assert_response :success
    body = response.parsed_body
    assert_empty body["users"]
  end

  # --- show ---

  test "show requires authentication" do
    get "/api/v1/users/#{@member.id}"
    assert_response :unauthorized
  end

  test "admin sees private fields for any user in show" do
    get "/api/v1/users/#{@member.id}", headers: auth(@admin)
    assert_response :success
    user = response.parsed_body["user"]
    assert_equal "mike@example.com", user["email"]
    assert_equal "1995-06-30", user["date_of_birth"]
    assert_nil user["password_digest"]
  end

  test "member sees own private fields in show" do
    get "/api/v1/users/#{@member.id}", headers: auth(@member)
    assert_response :success
    user = response.parsed_body["user"]
    assert_equal "mike@example.com", user["email"]
    assert_equal "1995-06-30", user["date_of_birth"]
  end

  test "member cannot see another user's private fields in show" do
    get "/api/v1/users/#{@admin.id}", headers: auth(@member)
    assert_response :success
    user = response.parsed_body["user"]
    assert_equal "AdaAdmin", user["username"]
    assert_nil user["email"]
    assert_nil user["date_of_birth"]
    assert_not user.key?("email")
    assert_not user.key?("date_of_birth")
  end

  test "show non-existent user returns 404" do
    get "/api/v1/users/0", headers: auth(@member)
    assert_response :not_found
    assert_equal "Not found", response.parsed_body["error"]
  end

  # --- create ---

  test "admin creates a user" do
    assert_difference "User.count", 1 do
      post "/api/v1/users", params: new_user_params, as: :json, headers: auth(@admin)
    end
    assert_response :created
    assert_equal "nina@example.com", response.parsed_body.dig("user", "email")
    assert_nil response.parsed_body["user"]["password_digest"]
  end

  test "admin can create an admin" do
    post "/api/v1/users", params: new_user_params(role: "admin"), as: :json, headers: auth(@admin)
    assert_response :created
    assert_equal "admin", response.parsed_body.dig("user", "role")
  end

  test "member cannot create a user" do
    assert_no_difference "User.count" do
      post "/api/v1/users", params: new_user_params, as: :json, headers: auth(@member)
    end
    assert_response :forbidden
    assert_equal "You are not authorized to perform this action", response.parsed_body["error"]
  end

  test "create returns 422 on validation failure" do
    post "/api/v1/users", params: new_user_params(email: "bad", username: "ab"), as: :json, headers: auth(@admin)
    assert_response :unprocessable_content
    assert response.parsed_body["errors"].key?("email")
  end

  test "create rejects username differing only by case" do
    post "/api/v1/users", params: new_user_params(username: "adaadmin"), as: :json, headers: auth(@admin)
    assert_response :unprocessable_content
    assert response.parsed_body["errors"].key?("username")
  end

  test "create without user key returns 400" do
    post "/api/v1/users", params: {}, as: :json, headers: auth(@admin)
    assert_response :bad_request
  end

  # --- update ---

  test "member updates own profile" do
    patch "/api/v1/users/#{@member.id}", params: { user: { first_name: "Michael" } }, as: :json, headers: auth(@member)
    assert_response :success
    assert_equal "Michael", @member.reload.first_name
    assert_equal "mike@example.com", response.parsed_body.dig("user", "email")
  end

  test "member cannot update another user" do
    patch "/api/v1/users/#{@other.id}", params: { user: { first_name: "Hax" } }, as: :json, headers: auth(@member)
    assert_response :forbidden
    assert_equal "You are not authorized to perform this action", response.parsed_body["error"]
    assert_not_equal "Hax", @other.reload.first_name
  end

  test "member cannot change own role" do
    patch "/api/v1/users/#{@member.id}", params: { user: { role: "admin" } }, as: :json, headers: auth(@member)
    assert_not @member.reload.admin?
  end

  test "admin updates any user and role" do
    patch "/api/v1/users/#{@other.id}", params: { user: { role: "admin", last_name: "Boss" } }, as: :json, headers: auth(@admin)
    assert_response :success
    assert @other.reload.admin?
    assert_equal "Boss", @other.last_name
  end

  test "update returns 422 on invalid data" do
    patch "/api/v1/users/#{@member.id}", params: { user: { email: "nope" } }, as: :json, headers: auth(@member)
    assert_response :unprocessable_content
  end

  test "update unknown user returns 404" do
    patch "/api/v1/users/0", params: { user: { first_name: "x" } }, as: :json, headers: auth(@admin)
    assert_response :not_found
  end
end
