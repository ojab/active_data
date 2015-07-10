module ActiveData
  module Model
    module Associations
      class CollectionProxy
        include Enumerable

        delegate :target, :save, :save!, :loaded?, :reload, :clear, :concat, to: :@association
        delegate :each, :size, :length, :first, :last, :empty?, :many?, :==, :dup, to: :target
        alias_method :<<, :concat
        alias_method :push, :concat

        def initialize(association)
          @association = association
        end

        def to_ary
          dup
        end
        alias_method :to_a, :to_ary

        def inspect
          entries = target.take(10).map!(&:inspect)
          entries[10] = '...' if target.size > 10

          "#<#{self.class.name} [#{entries.join(', ')}]>"
        end
      end
    end
  end
end
