module Pacer::Routes
  # This mixin allows an iterator to be returned from methods that perform a
  # transformation on the elements in their collection. Set the block property
  # to the proc that does the transformation.
  module IteratorBlockMixin
    # Set the block that does the transformation.
    def block=(block)
      @block = block
    end

    def next
      @block.call(super)
    end
  end
end
