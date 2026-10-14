# frozen_string_literal: true

module Api
  module V1
    class RegistrationsController < Api::BaseController
      skip_before_action :authenticate!, only: :create
      skip_after_action :verify_authorized, only: :create

      def create
        user = User.new(registration_params)
        user.role = :member # Enforce member role on public registration

        if user.save
          token = Auth.issuer.issue(user)

          render json: {
            token: token,
            token_type: "Bearer",
            expires_in: Auth.config.ttl_seconds,
            user: UserSerializer.render(user, viewer: user)
          }, status: :created
        else
          render_validation_errors(user)
        end
      end

      private

      def registration_params
        if params.key?(:user)
          params.require(:user).permit(
            :first_name, :last_name, :username, :email,
            :password, :password_confirmation, :date_of_birth
          )
        else
          params.permit(
            :first_name, :last_name, :username, :email,
            :password, :password_confirmation, :date_of_birth
          )
        end
      end
    end
  end
end
