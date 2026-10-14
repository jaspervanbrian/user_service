module Auth
  class << self
    def config
      @config ||= Config.new
    end

    def key_set
      @key_set ||= KeySet.new(config: config)
    end

    def issuer
      @issuer ||= TokenIssuer.new(config: config, key_set: key_set)
    end

    def verifier
      @verifier ||= case config.verifier_type.to_s
      when "gateway"
                      Verifiers::Gateway.new
      else
                      Verifiers::Local.new(config: config, key_set: key_set)
      end
    end

    # Resets memoized instances (useful in tests when testing different configurations)
    def reset!
      @config = nil
      @key_set = nil
      @issuer = nil
      @verifier = nil
    end
  end
end
