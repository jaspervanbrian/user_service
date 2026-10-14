module Api
  module V1
    class SessionsController < Api::BaseController
      skip_before_action :authenticate!, only: :create

      def create
        login = session_params[:login]
        password = session_params[:password]

        user = User.find_by_login(login)

        if user&.authenticate(password)
          token = Auth.issuer.issue(user)

          render json: {
            token: token,
            token_type: "Bearer",
            expires_in: Auth.config.ttl_seconds,
            user: UserSerializer.render(user, viewer: user)
          }, status: :created
        else
          # Mitigate timing side-channel attacks by running a dummy BCrypt comparison when user does not exist
          BCrypt::Password.create("dummy_pass", cost: BCrypt::Engine::MIN_COST) if user.nil?

          render json: { error: "Invalid credentials" }, status: :unauthorized
        end
      end

      private

      def session_params
        if params.key?(:user)
          params.require(:user).permit(:login, :password)
        else
          params.permit(:login, :password)
        end
      end
    end
  end
end
