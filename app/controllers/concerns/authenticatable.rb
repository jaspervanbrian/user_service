module Authenticatable
  extend ActiveSupport::Concern

  included do
    rescue_from Auth::Errors::InvalidToken, with: :render_unauthorized
  end

  def authenticate!
    return if current_user.present?

    render_unauthorized(Auth::Errors::InvalidToken.new("User not found"))
  end

  def current_claims
    @current_claims ||= Auth.verifier.verify(request)
  end

  def current_user
    @current_user ||= User.find_by(id: current_claims.user_id) if current_claims&.user_id
  end

  private

  def render_unauthorized(exception = nil)
    message = exception&.message || "Unauthorized"
    sanitized_message = message.gsub('"', "'")
    response.headers["WWW-Authenticate"] = %(Bearer error="invalid_token", error_description="#{sanitized_message}")

    render json: { error: message }, status: :unauthorized
  end
end
