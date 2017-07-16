# frozen_string_literal: true

module ArrayLargerThan
  class ArrayLargerThanMatcher
    def initialize(size)
      @size = size
    end

    def ===(other_array)
      other_array.size > @size
    end

    def description
      "an array with more than #{@size} elements"
    end
  end

  def array_larger_than(size)
    ArrayLargerThanMatcher.new(size)
  end
end

RSpec.configure do |config|
  config.include ArrayLargerThan
end
