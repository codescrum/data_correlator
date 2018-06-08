# Correlators are procs applied to one to one comparisons
# the correlator picks depending on the specified block
# return `true` to select, return `false` to reject
#
# These are common correlator functions
module DataCorrelator
  module Reporters
    def self.noop
      lambda{|x| x}
    end

    def self.inspect
      lambda{|x| x.inspect}
    end

    def self.id
      lambda{|x| x.id}
    end

    def self.email
      lambda{|x| x.email}
    end

    def self.name
      lambda{|x| x.name}
    end

    # 29:test@test.com
    def self.id_and_email
      lambda{|x| "#{x.id}:#{x.email}"}
    end

    def self.created_at
      lambda{|x| x.created_at}
    end

    # test@test.com:2015-08-12....
    def self.email_and_created_at
      lambda{|x| "#{x.email}:#{x.created_at}"}
    end
  end
end
