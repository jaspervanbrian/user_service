module Auth
  module Errors
    class ExpiredToken < InvalidToken
      def initialize(message = "Authentication token has expired")
        super(message)
      end
    end
  end
end
