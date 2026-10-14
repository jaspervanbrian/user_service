module Api
  module V1
    class UsersController < Api::BaseController
      def index
        authorize User
        result = Users::Paginate.call(
          cursor: params[:cursor],
          page: params[:page],
          limit: params[:limit],
          scope: policy_scope(User)
        )

        render json: {
          users: UserSerializer.render(result[:users], viewer: current_user),
          pagination: result[:pagination]
        }
      end

      def show
        user = User.find(params[:id])
        authorize user

        render json: { user: UserSerializer.render(user, viewer: current_user) }
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
    end
  end
end
