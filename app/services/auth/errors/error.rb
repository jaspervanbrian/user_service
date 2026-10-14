module Auth
  module Errors
    class Error < StandardError
      def initialize(message = "Authentication error")
        super(message)
      end
    end
  end
end
