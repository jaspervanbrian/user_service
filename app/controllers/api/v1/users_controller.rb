module Api
  module V1
    class UsersController < Api::BaseController
      def index
        authorize User
        result = Users::Paginate.call(
          cursor: params[:cursor],
          limit: params[:limit],
          scope: policy_scope(User)
        )

        render json: {
          users: UserSerializer.render(result[:users], viewer: current_user),
          pagination: result[:pagination]
        }
      end

      def create
        authorize User
        user = User.new(permitted_attributes(User))

        if user.save
          render json: { user: UserSerializer.render(user, viewer: current_user) }, status: :created
        else
          render_validation_errors(user)
        end
      end

      def update
        user = User.find(params[:id])
        authorize user

        if user.update(permitted_attributes(user))
          render json: { user: UserSerializer.render(user, viewer: current_user) }
        else
          render_validation_errors(user)
        end
      end

      private

      def render_validation_errors(user)
        render json: { errors: user.errors.to_hash }, status: :unprocessable_content
      end
    end
  end
end
