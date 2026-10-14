module Auth
  module Errors
    class MissingToken < InvalidToken
      def initialize(message = "Missing authentication token")
        super(message)
      end
    end
  end
end
