require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  class TestProtectedController < Api::BaseController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
      render json: { user_id: current_user.id, role: current_claims.role }
    end
  end

  setup do
    @user = users(:member)
    @token = Auth.issuer.issue(@user)
  end

  test "request without token returns 401 with WWW-Authenticate header" do
    with_test_route do
      get "/test_protected"
      assert_response :unauthorized
      assert_includes response.headers["WWW-Authenticate"], "Bearer"
      assert_equal "Missing authentication token", response.parsed_body["error"]
    end
  end

  test "request with valid Bearer token sets current_user and claims" do
    with_test_route do
      get "/test_protected", headers: { "Authorization" => "Bearer #{@token}" }
      assert_response :success
      assert_equal @user.id, response.parsed_body["user_id"]
      assert_equal "member", response.parsed_body["role"]
    end
  end

  test "request with expired token returns 401" do
    expired_token = Auth.issuer.issue(@user, ttl: -1)
    with_test_route do
      get "/test_protected", headers: { "Authorization" => "Bearer #{expired_token}" }
      assert_response :unauthorized
      assert_includes response.parsed_body["error"], "expired"
    end
  end

  test "request with tampered token returns 401" do
    with_test_route do
      get "/test_protected", headers: { "Authorization" => "Bearer #{@token}invalid" }
      assert_response :unauthorized
      assert_includes response.parsed_body["error"], "Invalid"
    end
  end

  private

  def with_test_route
    Rails.application.routes.draw do
      get "/test_protected", to: "authentication_test/test_protected#index"
      get "/.well-known/jwks.json", to: "jwks#show"
      namespace :api do
        namespace :v1 do
          resource :sessions, only: :create
          resource :registrations, only: :create
          resources :users, only: %i[index show create update]
        end
      end
    end
    yield
  ensure
    Rails.application.reload_routes!
  end
end
