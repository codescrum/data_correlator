# This module provides
module DataCorrelator

  module Correlations

    extend ActiveSupport::Concern

    def quick_correlation_and_disambiguation_mapping_with_reporters(set_a, set_b, reporter_a, reporter_b, *strategies, &block)
      reporting_wrap(set_a, set_b.map(&reporter_b)) do
        quick_correlation_and_disambiguation_with_reporters(set_a, set_b, reporter_a, reporter_b, *strategies, &block)
      end
    end

    def quick_correlation_and_disambiguation_mapping(set_a, set_b, *strategies, &block)
      reporting_wrap(set_a, set_b) do
        quick_correlation_and_disambiguation(set_a, set_b, *strategies, &block)
      end
    end

    # Same as `quick_correlation_and_disambiguation`, but with reporters, as usual
    def quick_correlation_and_disambiguation_with_reporters(set_a, set_b, reporter_a, reporter_b, *strategies, &block)
      quick_correlation_and_disambiguation_core(strategies, block) do |new_strategies, stop_condition|
        deep_disambiguation_with_reporters(set_a, set_b, reporter_a, reporter_b, *new_strategies, &stop_condition)
      end
    end

    # This method converts the first strategy in `strategies` into
    # a `colleration_strategy`
    # Also identifies if no original stop_condition block was passed.
    # If no `stop_condition`, assigns a default stop condition which
    # only checks too see if one element is already present in the
    # results, to not continue doing anything.
    #
    def quick_correlation_and_disambiguation_core(strategies, stop_condition, &block)
      correlation_strategy = strategies.shift # take the first one
      # convert the correlation to a disambiguation
      correlation_strategy_equivalent = lambda{|a,bs| bs.select{|b| correlation_strategy.call(a,b)}}

      # Put it back in place, where it was, now converted
      strategies = strategies.prepend correlation_strategy_equivalent
      default_stop_condition = lambda{|a,bs| bs.count > 1} # unique element condition

      if stop_condition.respond_to? :call
        yield(strategies, stop_condition) # custom disambiguation "apply while... whatever the block says"
      else
        yield(strategies, default_stop_condition) # disambiguate while there are still multiple elements
      end
    end

    # A shorthand method to do a correlation and then, apply disambiguation
    # What it does:
    #
    # 1. Correlates set_a (A) and set_b (B) transforming the first of `strategies`
    #    into a `correlation_strategy`.
    # 2. The result is then applied the subsequent `*disambiguation_strategies`
    #    so that you can further filter/modify each group of correlated elements
    # 3. If no block is specified, it will keep applying disambiguation strategies
    #    until the correlated objects map one-to-one, or all the strategies are used.
    #
    #    If you specify a block, the block determines the condition in which the
    #    sequential disambiguations have to continue to be applied.
    #
    def quick_correlation_and_disambiguation(set_a, set_b, *strategies, &block)
      quick_correlation_and_disambiguation_core(strategies, block) do |new_strategies, stop_condition|
        deep_disambiguation(set_a, set_b, *new_strategies, &stop_condition)
      end
    end

    # [WARNING]: Potentially intensive computation
    #
    # return a hash with the following information:
    # {
    #   :summary =>
    #     {
    #       :one_to_one_count       => 2                  # one to one count
    #       :one_to_many_count      => 1                  # one to many count
    #       :no_correlation_a_count => 2                  # number of elements from A which did not have any correlated elements in B
    #       :no_correlation_b_count => 1                  # number of elements from B which did not have any correlated elements in A
    #       :time                   => 12.92              # time, in seconds, which this operation took to run
    #     }
    #   :one_to_one             => { a1 => b1, a2 => b2 } # one to one ready to use
    #   :one_to_many            => { a3: [b3, b4] }       # one to many correlations
    #   :no_correlation_a       => [a5, a6]               # elements from A which did not have any correlated elements in B
    #   :no_correlation_b       => [b7]                   # elements from B which did not have any correlated elements in A
    # }
    # @param set_a [Array] an array of objects (the A set) to act as keys in the final hash
    # @param set_b [Array] an array of objects (the B set) to be correlated with elements from A
    def deep_correlation_mapping(set_a, set_b, *strategies, &block)
      reporting_wrap(set_a, set_b) do
        deep_correlation(set_a, set_b, *strategies, &block)
      end
    end

    # [WARNING]: Potentially intensive computation
    #
    # Same as deep_correlation_mapping, but instead of returning the actual objects
    # it returns the mapped objects modified as per the corresponding reporters
    # e.g.
    #
    def deep_correlation_mapping_with_reporters(set_a, set_b, reporter_a, reporter_b, *strategies, &block)
      reporting_wrap(set_a, set_b.map(&reporter_b)) do
        deep_correlation_with_reporters(set_a, set_b, reporter_a, reporter_b, *strategies, &block)
      end
    end

    # TEMPORAL NAME: reporting_wrap
    # Works with both correlation or disambiguation!
    # TODO: CODE IS NOT INDEPENDANT OF USAGE!
    # do not place reporters in the low level methods
    # e.g. element_correlation_with_reporter, only apply them here, at the end?
    # set_b has to be pre-mapped with the original repoters, in order to work
    def reporting_wrap(set_a, set_b, &block)
      mapping = {}
      summary = {}
      one_to_one  = {}
      one_to_many = {}
      no_correlation_a = []
      no_correlation_b = []

      # compute the correlationresult
      processed_result = yield

      # Doing this in an each block to not abuse use of loops
      # TODO: Check if this really saves some processing
      allocated_bs = [] # keep track of associated B elements
      processed_result.each do |a, bs|
        if bs.count.zero? # nothing here
          no_correlation_a << a
        elsif bs.count == 1 # one to one match # what we really want
          element = bs.first
          allocated_bs << element
          one_to_one[a] = element
        elsif bs.count > 1 # one to many match
          allocated_bs += bs
          one_to_many[a] = bs
        else
          raise 'Cannot know which case is this!'
        end
      end

      # see which elements of the B set were not used
      # we have mapped the original `set_b` to whatever the reporter outcomes
      # there is
      no_correlation_b = set_b - allocated_bs


      summary[:one_to_one_count] = one_to_one.count
      summary[:one_to_many_count] = one_to_many.count
      summary[:no_correlation_a_count] = no_correlation_a.count
      summary[:no_correlation_b_count] = no_correlation_b.count

      # provide the summary first (when debugging, useful)
      mapping[:summary] = summary

      # now provide the actual mapping result
      mapping[:one_to_one]  = one_to_one
      mapping[:one_to_many] = one_to_many
      mapping[:no_correlation_a] = no_correlation_a
      mapping[:no_correlation_b] = no_correlation_b

      mapping
    end

    # Same as deep_correlation_mapping, but instead of returning the actual objects
    # it returns the mapped objects modified as per the corresponding block
    # e.g. supposing that you have the following reporter objects
    #
    #  reporter_a = lambda{|a| a.id}
    #  reporter_b = lambda{|b| b.email}
    #
    # it will return something like:
    #
    #   {0 => ["A_0@test.com"], 1 => ["A_1@test.com"]}
    #
    # instead of the entire objects that this information could come from
    # useful for: debugging and checking
    #
    def deep_correlation_with_reporters(set_a, set_b, reporter_a, reporter_b, *strategies, &block)
      Hash[set_a.map{|a| [reporter_a.call(a), deep_element_correlation_with_reporter(a, set_b, reporter_b, *strategies, &block)]}]
    end


    # Apply the #deep_element_correlation method with multiple strategies
    # to two sets (A and B) as you would expect
    # @param set_a [Array] an array of objects (the A set) to act as keys in the final hash
    # @param set_b [Array] an array of objects (the B set) to be correlated with elements from A
    def deep_correlation(set_a, set_b, *strategies, &block)
      Hash[set_a.map{|a| [a, deep_element_correlation(a, set_b, *strategies, &block)]}]
    end

    # Recursively apply correlation to elements of the B set
    # at each stage, ask the block if it needs to continue
    # applying the next strategy or not
    #
    # Useful to recursively filter and disambiguate correlations results
    # by trying new strategies at each stage, for the given elements of B that
    # still require more checks to pass according to a particular element of A.
    #
    # if no block is given, all strategies are eventually applied
    # same as #deep_correlation_with_reporter, but with no passed in reporter
    def deep_element_correlation(a, set_b, *strategies, &block)
      deep_element_correlation_with_reporter(a, set_b, nil, *strategies, &block)
    end

    # recursively apply correlation to elements of the B set
    # at each stage, ask the block if it needs to continue
    # applying the next strategy or not
    #
    # Useful to recursively filter and disambiguate correlations results
    # by trying new strategies at each stage, for the given elements of B that
    # still require more checks to pass according to a particular element of A.
    #
    # if no block is given, all strategies are eventually applied
    # if reporter is strictly passed as `nil`
    # then the reporter function is not used nor required.
    def deep_element_correlation_with_reporter(a, set_b, reporter, *strategies, &block)
      raise 'Element reporter is not a callable object!' unless reporter.respond_to?(:call) || reporter.nil?
      raise 'Correlation strategies are not all callable objects!' unless strategies.all?{|strategy| strategy.respond_to?(:call)}

      # get the current strategy
      current_strategy = strategies.shift

      # Apply the next strategy if no block or if a block
      # is present and evaluates to true
      apply_next = !block_given? || yield(a, set_b)

      # if the condition is not met, return the same set_b
      # which is the same as "last elements passed in"
      if !apply_next
        return reporter ? set_b.map(&reporter) : set_b
      end

      if strategies.count.zero? # no more strategies left
        correlated_elements = correlate_element(a, set_b, &current_strategy)
        reporter ? correlated_elements.map(&reporter) : correlated_elements
      else
        deep_element_correlation_with_reporter(a, correlate_element(a, set_b, &current_strategy), reporter, *strategies, &block)
      end
    end

    ########## Correlation methods apply to any type of object, not only virtus!

    # Returns a hash associating (i.e. correlating)
    # elements from A with ZERO OR MORE elements from B
    # if zero (0) `b`s match a given `a`,
    # then the `a` is associated with empty array [].
    # e.g.
    #
    # @param set_a [Array] an array of objects (the A set) to act as keys in the final hash
    # @param set_b [Array] an array of objects (the B set) to be correlated with elements from A
    def correlate(set_a, set_b, &block)
      raise "Cannot correlate without a block, please pass a block!" unless block_given?
      Hash[set_a.map{|a| [a, correlate_element(a, set_b, &block)]}]
    end

    # Correlate element
    def correlate_element(a, set_b, &block)
      set_b.select{|b| yield(a, b)}
    end

    # returns elements from A with their
    # corresponding elements from B
    # example:
    # Assuming an existant correlation/mapping between the source and elements from B
    # like so: {a: [], b: [], c: [1], d: [1], e: [1,2], f: [1,2,3]}
    # where :a, :b, :c... are the `a`s and 1,2,3... the `b`s
    # it will output:
    # {
    #   0 => [{:a=>[]}, {:b=>[]}],    # `a`s with 0 correlated objects (no match)
    #   1 => [{:c=>[1]}, {:d=>[1]}],  # `a`s with 1 correlated object (perfect match)
    #   2 => [{:e=>[1, 2]}],          # `a`s with 2 correlated objects (2 ambiguous matches)
    #   3 => [{:f=>[1, 2, 3]}]}       # `a`s with 3 correlated objects (3 ambiguous matches)
    #   ...                           # etc..
    # }
    #
    def correlation_frequency_mapping(set_a, set_b, &block)
      Hash[correlate(set_a, set_b, &block).map{|k,v| [k, v.map{|vv| {vv.first => vv.last} }]}]
    end


    ################ DISAMBIGUATION METHODS ###############

    # [NOTE]
    #
    # Disambiguation is a generalization of correlation
    # it gives you the power to basically, nest arbitrary operations
    # that apply to the subsequent array of "correlated" (i.e. "chosen")
    # elements.
    #
    # The *strategies can be used to perform operations at each
    # disambiguation stage similarly to correlation, but the
    # difference is that they yield the entire set as the second parameter
    # instead of just the individual elements.
    #
    # You can transform any arbitrary correlation oeprations
    # (even deep correlations) into disambiguations, but it is
    # NOT possible to transform arbitrary disambiguation operations
    # into correlations. They are fundamentally different.
    #
    # Disambiguation and correlation strategies are different in this way:
    #
    # correlation_strategy:    lambda{|a,b | ... } # a with single b
    # disambiguation_strategy: lambda{|a,bs| ... } # a with multiple b
    #
    # The deep disambiguation methods take the results of the block
    # of the previous strategy, and apply it to the next.
    #
    # You can transform a deep correlation computation by to disambiguation
    # strategies like this:
    #
    # correlation_strategy:    lambda{|a,b| <logic> }
    # disambiguation_strategy: lambda{|a,bs| bs.select{|a,b| <logic> } } # equivalent
    #
    # For the purpose of this reading, in disambiguation strategies:
    # make sure to *always* return an array of objects from the disambiguation strategy.


    # even more useful than correlation methods.
    # Ask Miguel Diaz - gato_omega for details
    # see the [NOTE] at the beggining of this section
    # for a brief introduction to these methods
    def deep_disambiguation_mapping(set_a, set_b, *strategies, &block)
      reporting_wrap(set_a, set_b, set_b) do
        deep_disambiguation(set_a, set_b, *strategies, &block)
      end
    end

    # even more useful than correlation methods.
    # Ask Miguel Diaz - gato_omega for details
    # see the [NOTE] at the beggining of this section
    # for a brief introduction to these methods
    def deep_disambiguation_mapping_with_reporters(set_a, set_b, reporter_a, reporter_b, *strategies, &block)
      reporting_wrap(set_a, set_b.map(&reporter_b)) do
        deep_disambiguation_with_reporters(set_a, set_b, reporter_a, reporter_b, *strategies, &block)
      end
    end

    # even more useful than correlation methods.
    # Ask Miguel Diaz - gato_omega for details
    # see the [NOTE] at the beggining of this section
    # for a brief introduction to these methods
    def deep_disambiguation_with_reporters(set_a, set_b, reporter_a, reporter_b, *strategies, &block)
      Hash[set_a.map{|a| [reporter_a.call(a), deep_element_disambiguation_with_reporter(a, set_b, reporter_b, *strategies, &block)]}]
    end

    # even more useful than correlation methods.
    # Ask Miguel Diaz - gato_omega for details
    # see the [NOTE] at the beggining of this section
    # for a brief introduction to these methods
    def deep_disambiguation(set_a, set_b, *strategies, &block)
      Hash[set_a.map{|a| [a, deep_element_disambiguation(a, set_b, *strategies, &block)]}]
    end


    # even more useful than correlation methods.
    # Ask Miguel Diaz - gato_omega for details
    # see the [NOTE] at the beggining of this section
    # for a brief introduction to these methods
    def deep_element_disambiguation(a, set_b, *strategies, &block)
      deep_element_disambiguation_with_reporter(a, set_b, nil, *strategies, &block)
    end


    # even more useful than correlation methods.
    # Ask Miguel Diaz - gato_omega for details
    # see the [NOTE] at the beggining of this section
    # for a brief introduction to these methods
    def deep_element_disambiguation_with_reporter(a, set_b, reporter, *strategies, &block)
      raise 'Element reporter is not a callable object!' unless reporter.respond_to?(:call) || reporter.nil?
      raise 'Correlation strategies are not all callable objects!' unless strategies.all?{|strategy| strategy.respond_to?(:call)}

      # get the current strategy
      current_strategy = strategies.shift

      # Apply the next strategy if no block or if a block
      # is present and evaluates to true
      apply_next = !block_given? || yield(a, set_b)

      # if the condition is not met, return the same set_b
      # which is the same as "last elements passed in"
      if !apply_next
        return reporter ? set_b.map(&reporter) : set_b
      end

      if strategies.count.zero? # no more strategies left
        disambiguated_elements = current_strategy.call(a, set_b)
        reporter ? disambiguated_elements.map(&reporter) : disambiguated_elements
      else
        deep_element_disambiguation_with_reporter(a, current_strategy.call(a, set_b), reporter, *strategies, &block)
      end
    end
  end # module Correlations
end # module DataCorrelator
