# Correlators are procs applied to one to one comparisons
# the correlator picks depending on the specified block
# return `true` to select, return `false` to reject
#
# These are common correlator functions
module DataCorrelator
  module Correlators
    def self.same_id
      lambda{|a,b| a.id == b.id}
    end

    def self.same_email
      lambda{|a,b| a.email == b.email}
    end

    def self.same(field)
      lambda{|a,b| a.__send__(field) == b.__send__(field)}
    end

    def self.same_id
      lambda{|a,b| a.id == b.id}
    end

    def self.same_email
      lambda{|a,b| a.email == b.email}
    end

    def self.same_name
      lambda{|a,b| a.name == b.name}
    end

    # correlates using the created_at truncated at 0 secs to avoid accuracy problems
    # when taking data from different sources and precision
    def self.same_created_at_with_minute_tolerance
      lambda{|a,b| a.created_at.change(sec: 0) == b.created_at.change(sec: 0)}
    end

    # correlates using the updated_at truncated at 0 secs to avoid accuracy problems
    # when taking data from different sources and precision
    def self.same_updated_at_with_minute_tolerance
      lambda{|a,b| a.updated_at.change(sec: 0) == b.updated_at.change(sec: 0)}
    end

  end
end
