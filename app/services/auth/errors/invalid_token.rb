module Auth
  module Errors
    class InvalidToken < Error
      def initialize(message = "Invalid authentication token")
        super(message)
      end
    end
  end
end
