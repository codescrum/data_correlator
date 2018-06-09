# Disambiguators are procs applied to one to many correlation outputs
# the disambiguator picks one or more of the correlated elements
# depending on the specified block, essentially filtering the ouput even more
# return the elements that need to proceed as the correlated output
# you may apply several disambiguators to "tunnel" the final output
#
# These are common disambiguator functions
#
# IMPORTANT NOTE TO SELF: CORRELATION AND DISAMBIGUATION ARE THE SAME THING!
# THE CONCEPT IS THE SAME, APPLYING SELECTOR-FUNNEL FUNCTIONS TO DATA
module DataCorrelator
  module Disambiguators
    def self.pick_last_created_at
      lambda{|a,bs| [bs.sort{|x,y| x.created_at <=> y.created_at}.last] }
    end

    def self.pick_last
      lambda{|a,bs| [bs.last] }
    end

    def self.pick_last_same_created_at_with_minute_tolerance
      lambda{|a,bs| [bs.select{|b| a.created_at.change(sec: 0) == b.created_at.change(sec: 0)}.sort{|x,y| x.created_at <=> y.created_at}.last] }
    end

    def self.pick_same_created_at_with_minute_tolerance
      lambda{|a,bs| bs.select{|b| b.created_at.change(sec: 0) == a.created_at.change(sec: 0)} }
    end
  end
end
