# This class is only a container for common strategies
# The strategies themselves can be check at data_correlator/strategies/*.rb
module DataCorrelator
  class Strategy
    def self.[]=(strategy_name, strategy_proc)
      @@strategies ||= {}
      @@strategies[strategy_name.to_sym] = strategy_proc
    end

    def self.[](strategy_name)
      @@strategies ||= {}
      @@strategies[strategy_name.to_sym]
    end
  end
end
