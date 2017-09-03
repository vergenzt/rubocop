# frozen_string_literal: true

module RuboCop
  # This class represents a disabled source range for a single cop configured
  # using CommentDirectives.
  class CommentConfigRange < Range
    attr_reader :cop_name
    attr_reader :begin_directive
    attr_reader :end_directive

    def initialize(cop_name, begin_directive, end_directive = nil)
      @cop_name = cop_name
      @begin_directive = begin_directive
      @end_directive = end_directive

      if end_directive.nil?
        super(begin_directive.line, Float::INFINITY)
      else
        super(begin_directive.line, end_directive.line)
      end
    end

    def single_line?
      begin_directive == end_directive
    end
  end
end
