module Auth
  module Errors
    class ConfigurationError < Error
      def initialize(message = "Invalid authentication configuration")
        super(message)
      end
    end
  end
end
