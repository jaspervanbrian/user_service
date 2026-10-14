module Api
  class BaseController < ApplicationController
    include Authenticatable
    include Pundit::Authorization

    before_action :authenticate!
    after_action :verify_authorized, unless: -> { action_name == "index" }
    after_action :verify_policy_scoped, if: -> { action_name == "index" }

    rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
    rescue_from ActiveRecord::RecordNotUnique, with: :render_conflict
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

    private

    def render_forbidden(_exception = nil)
      render json: { error: "You are not authorized to perform this action" }, status: :forbidden
    end

    def render_not_found(_exception = nil)
      render json: { error: "Not found" }, status: :not_found
    end

    def render_bad_request(exception)
      render json: { error: exception.message }, status: :bad_request
    end

    # Raised when a DB unique index is hit in a race the model validation could not catch.
    def render_conflict(_exception = nil)
      render json: { errors: { base: [ "username or email has already been taken" ] } },
             status: :unprocessable_content
    end

    def render_record_invalid(exception)
      render_validation_errors(exception.record)
    end

    def render_validation_errors(record)
      render json: { errors: record.errors.to_hash }, status: :unprocessable_content
    end
  end
end
