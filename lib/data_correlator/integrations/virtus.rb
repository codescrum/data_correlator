# This module provides
module DataCorrelator

  module Integrations
    module Virtus
      extend ActiveSupport::Concern
      include ::DataCorrelator::Mappers

      # Applies #virtus_patch to an array of objects, based on another array
      # The objects patch themselves whenever the passed in block evaluates to true
      # passing a block is required
      # @param sources can be any virtus object
      # @param targets can be any virtus object (of the same class as source)
      def virtus_patch_multiple(sources, targets, options = {}, &block)
        # raise "Cannot virtus-patch multiple objects without knowing how to correlate them, please pass a block!" unless block_given?

        # # make strategy required
        # # to avoid silly mistakes
        # strategy = options[:strategy]
        # raise "Cannot virtus-patch multiple objects without applying a selection strategy in case of multiple associated targets" unless strategy

        # if strategy.is_a?(Symbol)
        #   # search in built-in strategies

        # elsif strategy.respond_to?(:call)

        # else
        #   raise "Strategy #{strategy} is not a valid strategy identifier, nor is it a callable object"
        # end
        # mapping = correlation_frequency_mapping(sources, targets, &block)
        # # virtus_patch(source, target)
      end

      # virtus compare!
      # def virtus_compare(a, b)

      # end

      # takes two trees of nested "associated" virtus objects
      def virtus_deep_compare(tree_a, tree_b)

        errors = []

        unless tree_a.size == tree_a.size
          puts "COMPARISSON FAILED -> trees are not the same size [#{tree_a.first.class.name}] vs [#{tree_b.first.class.name}]"
          binding.pry
          1
        end

        element_count = tree_a.size

        element_count.times do |record_number|
          a = tree_a.shift
          b = tree_b.shift

          unless a.class == b.class
            error = "COMPARISSON FAILED -> elements are not the same class at element #{record_number}, comparing: `#{a.class.name}` with `#{b.class.name}`"
            errors << error
            puts error
            binding.pry
            1
          end

          if !a.nil? && !b.nil?

            # get the attribute set
            attribute_set = a.class.attribute_set
            single_attributes = attribute_set.reject do |attribute| #read: 'reject'
              attribute.is_a? Virtus::Attribute::Collection # single attribute (NOT a collection)
            end

            simple_attributes = single_attributes.reject{|attribute| attribute.is_a? Virtus::Attribute::EmbeddedValue}

            a_attributes = a.attributes.slice(*simple_attributes.map(&:name))
            b_attributes = b.attributes.slice(*simple_attributes.map(&:name))

            if a_attributes == b_attributes
              # everything good
            else
              error = "COMPARISSON FAILED -> elements do not have the same simple attributes, opening a binding.pry console for more info..."
              errors << error
              binding.pry
              1
            end

            embedded_attributes = single_attributes.select{|attribute| attribute.is_a? Virtus::Attribute::EmbeddedValue}

            embedded_attributes.map(&:name).each do |embedded_attribute|
              virtus_deep_compare([a.__send__(embedded_attribute)], [b.__send__(embedded_attribute)])
            end

            # collection attributes
            collection_attributes = attribute_set.select do |attribute| #read: 'select'
              attribute.is_a? Virtus::Attribute::Collection # collection attribute (IT IS a collection)
            end

            collection_attributes.map(&:name).each do |collection_attribute|
              if virtus_deep_compare(a.__send__(collection_attribute), b.__send__(collection_attribute))
                #everything good
              else
               error = "COMPARISSON FAILED -> element subcollection #{collection_attribute} are not the same!, opening a binding.pry console for more info..."
               errors << error
               binding.pry
               1
              end
            end

          end


        end

        true unless errors.any?

      end

      # Takes attributes from a source virtus object and
      # patches the target object but does NOT change any
      # of the already present attributes
      # in the target object
      # it just 'fills the gaps' (using #present? to check)
      # returns a hash with:
      # easy_diff between the attributes
      # a new object (the patched target)
      # {diff: updated_attributes, result: new_virtus_object}
      #
      # @param target can be any virtus object (even a from a different class)
      # @param options let's you specify some of the following:
      #
      # options[:with] [Symbol] *required
      #   specifies the source target to use to patch the target
      # options[:presence_method] [Symbol]
      #   which method to use to decide wheter an attribute value is present or not
      #   in the `target` and `source` objects
      #   defaults to `:present?`, but you could also use `:nil?` if you are worried
      #   about overwriting empty strings (''), empty arrays ([]) or false values.
      #
      # options[:only] [Array][Symbol]
      #   which attributes from `source` to patch on `target`
      #   this way you patch exactly the attributes you want
      #   the opposite of `options[:except]`
      #
      # options[:except] [Array][Symbol]
      #   which attributes from `source` to NOT patch on target
      #   even if they do not exist on `target`, the opposite of `options[:only]`
      def virtus_patch(target, options)

        # assign default behavior
        source = options[:with]
        presence_method = options[:presence_method] || :present?
        only = options[:only] || []
        except = options[:except] || []

        # raise error if you do not specify the `:with` option
        raise 'Please provide a source object to patch the target with, like this: (virtus_patch(target, with: source)' unless source

        # Using both options is ambiguos, raise an error if this is the case.
        raise 'Please specify only one of `only` or `except`, not both' if only.any? && except.any?

        # Store the result
        result = {}

        # check which attributes from the target we want to preserve
        target_present_attributes = target.attributes.select{|k,v| v.__send__ presence_method}

        # check which ones of the source are available
        source_present_attributes = source.attributes.select{|k,v| v.__send__ presence_method}

        # check which ones that the source has are NOT present in the target
        # the "attributes to fill" in target, from source
        attributes_to_fill = source_present_attributes.reject{|k,v| target_present_attributes.include?(k)}

        attributes_to_fill = attributes_to_fill.slice(*only) if only.any?
        attributes_to_fill = attributes_to_fill.slice(*except) if except.any?

        new_attributes = target_present_attributes.merge attributes_to_fill

        # Produce a new object, of the same class as the target
        # with the new_attributes
        new_object = target.class.new(new_attributes)
        result[:object] = new_object

        # gimme the diff # => original.easy_diff modified
        removed_attributes, new_attributes = target_present_attributes.easy_diff(new_attributes)
        raise "Somehow, a virtus patch modified existing target attributes, please check!" unless removed_attributes.empty?
        result[:diff] = new_attributes # only :added should exit
        result
      end
    end # module Virtus
  end # module Integrations
end # module DataCorrelator
