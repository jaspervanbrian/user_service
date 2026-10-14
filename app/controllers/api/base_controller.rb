module Api
  class BaseController < ApplicationController
    include Authenticatable
    include Pundit::Authorization

    before_action :authenticate!

    rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

    private

    def render_forbidden(exception = nil)
      render json: { error: exception&.message || "Forbidden" }, status: :forbidden
    end
  end
end
