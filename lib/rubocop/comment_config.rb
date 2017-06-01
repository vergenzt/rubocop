# frozen_string_literal: true

module RuboCop
  # This class parses the special `rubocop:disable` comments in a source
  # and provides a way to check if each cop is enabled at arbitrary line.
  class CommentConfig
    attr_reader :processed_source
    attr_reader :cop_disabled_line_ranges

    def initialize(processed_source)
      @processed_source = processed_source
      compute_cop_disabled_ranges
      freeze
    end

    def cop_enabled_at_line?(cop, line_number)
      cop = cop.cop_name if cop.respond_to?(:cop_name)
      disabled_line_ranges = cop_disabled_line_ranges[cop]
      return true unless disabled_line_ranges

      disabled_line_ranges.none? { |range| range.include?(line_number) }
    end

    def directives
      @directives ||= (processed_source.comments || []).map do |comment|
        CommentDirective.from_comment(comment)
      end.compact
    end

    private

    def compute_cop_disabled_ranges
      # cop_name => [ranges]
      @cop_disabled_line_ranges = Hash.new { |h, k| h[k] = Array.new }

      # cop_name => disable_directive
      @cops_currently_disabled = Hash.new

      directives.each do |directive|
        case [directive_scope(directive), directive.keyword]
        when [:single_line, :disable]
          handle_single_line_disable(directive)
        when [:single_line, :enable]
          handle_single_line_enable(directive)
        when [:multi_line, :disable]
          handle_multi_line_disable(directive)
        when [:multi_line, :enable]
          handle_multi_line_enable(directive)
        else
          raise 'Unrecognized directive scope/keyword combo'
        end
      end

      @cops_currently_disabled.each do |cop_name, disable_directive|
        add_disabled_range(cop_name, disable_directive)
      end
    end

    def directive_scope(directive)
      if non_comment_token_line_numbers.include?(directive.line)
        :single_line
      else
        :multi_line
      end
    end

    def handle_single_line_disable(directive)
      directive.cop_names.each do |cop_name|
        add_disabled_range(cop_name, directive, directive)
      end
    end

    def handle_single_line_enable(directive)
      # Single-line enable statements not supported. Do nothing.
    end

    def handle_multi_line_disable(directive)
      # Handle any cops already disabled on this line, ending the current
      # disabled ranges before starting new ranges.
      handle_multi_line_enable(directive)

      directive.cop_names.each do |cop_name|
        @cops_currently_disabled[cop_name] = directive
      end
    end

    def handle_multi_line_enable(directive)
      disabled_cops_in(directive).each do |cop_name|
        begin_directive = @cops_currently_disabled.delete(cop_name)
        add_disabled_range(cop_name, begin_directive, directive)
      end
    end

    def disabled_cops_in(directive)
      directive.cop_names & @cops_currently_disabled.keys
    end

    def add_disabled_range(cop_name, begin_directive, end_directive = nil)
      begin = begin_directive.line
      end = end_directive ? end_directive.line : Float::INFINITY
      range = begin..end
      @cop_disabled_line_ranges[cop_name] <<= range
    end

    def non_comment_token_line_numbers
      @non_comment_token_line_numbers ||= begin
        non_comment_tokens = processed_source.tokens.reject do |token|
          token.type == :tCOMMENT
        end

        non_comment_tokens.map { |token| token.pos.line }.uniq
      end
    end
  end
end
