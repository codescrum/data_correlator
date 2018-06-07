# Provides Virtus models with some introspection methods
# commonly needed when using correlation methods with models
module DataCorrelator

  module Extensions
    module Virtus
      extend ActiveSupport::Concern

      included do
        cattr_accessor :relational_attribute_names
        cattr_accessor :simple_attribute_names
      end

      class_methods do

        # compute and memoize the simple attributes
        # TODO: check out other information on the "attribute set",
        # perhaps it can be done even simpler.
        def simple_attributes
          self.simple_attribute_names ||= attribute_set.reject do |attribute| #read: 'reject'
            # NOT a collection, or an embedded type
            attribute.is_a?(Virtus::Attribute::Collection) ||
            attribute.is_a?(Virtus::Attribute::EmbeddedValue) ||
            attribute.name =~ /(^id|_ids?)$/ ||
            attribute.name =~ /(csv_row_number|errors)/ # no `csv_row_number` or `errors` fields
          end.map(&:name)
        end
        end

        # return the attributes that only represent the isolated virtus object itself
        # strip any `id`, `*_id` or `*_ids` or embedded collection or single relations
        def simple_attributes
        self.attributes.slice(*self.class.simple_attributes)
        end

        # compute and memoize the relational attributes
        # TODO: check out other information on the "attribute set",
        # perhaps it can be done even simpler.
        def relational_attributes
          self.relational_attribute_names ||= attribute_set.select do |attribute| #read: 'reject'
            # NOT a collection, or an embedded type
            attribute.is_a?(Virtus::Attribute::Collection) ||
            attribute.is_a?(Virtus::Attribute::EmbeddedValue) ||
            attribute.name =~ /(^id|_ids?)$/ ||
            attribute.name !~ /errors/     # no errors please
          end.map(&:name)
        end
      end

      # return the attributes that only represent the isolated virtus object itself
      # strip any `id`, `*_id` or `*_ids` or embedded collection or single relations
      def relational_attributes
        self.attributes.slice(*self.class.relational_attributes)
      end
    end
  end
end

#
module RecoveryInfo::Mixins::VirtusSimpleAttributes
  extend ActiveSupport::Concern



  class_methods do

end