class JwksController < ApplicationController
  def show
    expires_in 1.hour, public: true
    render json: Auth.key_set.to_jwks
  end
end
