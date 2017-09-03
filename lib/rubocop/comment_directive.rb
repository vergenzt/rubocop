# frozen_string_literal: true

module RuboCop
  # This class represents a single a `rubocop:*` comment directive.
  class CommentDirective
    UNNEEDED_DISABLE = 'Lint/UnneededDisable'.freeze

    # The available keywords to come after `# rubocop:`.
    KEYWORDS = %i[disable enable].freeze

    KEYWORD_PATTERN = "(?<keyword>#{KEYWORDS.join('|')})\\b".freeze
    COP_NAME_PATTERN = '(?<cop_name>([A-Z]\w+/)?(?:[A-Z]\w+))'.freeze
    COP_SEPARATOR_PATTERN = '(?<separator>\s*,\s*)'.freeze
    COP_NAMES_PATTERN =
      "(?:#{COP_NAME_PATTERN}#{COP_SEPARATOR_PATTERN})*#{COP_NAME_PATTERN}"
      .freeze
    COPS_PATTERN = "(?<cops_string>all|#{COP_NAMES_PATTERN})".freeze
    DESC_PATTERN = '(?<description>.*)'.freeze

    COMMENT_DIRECTIVE_REGEXP = Regexp.new(
      "# rubocop : #{KEYWORD_PATTERN} #{COPS_PATTERN} #{DESC_PATTERN}$"
        .gsub(' ', '\s*')
    )

    # Initializes a new CommentDirective if the provided Parser::Source::Comment
    # contains a directive. Returns nil if it does not.
    def self.from_comment(comment)
      return unless comment && comment.text =~ COMMENT_DIRECTIVE_REGEXP
      new(comment, Regexp.last_match)
    end

    def initialize(comment, match)
      @comment = comment
      @comment_range = comment.loc.expression
      @source_range = offset_range(@comment_range, *match.offset(0))
      @keyword = match[:keyword].to_sym
      @all_cops = match[:cops_string] == 'all'
      @description = match[:description]

      parse_cop_names(match)

      freeze
    end

    attr_reader :comment
    attr_reader :comment_range
    attr_reader :source_range
    attr_reader :keyword
    attr_reader :all_cops
    attr_reader :cop_names
    attr_reader :description

    alias all_cops? all_cops

    def line
      source_range.line
    end

    def cop_range(cop_name)
      @cop_name_ranges[cop_name] unless all_cops?
    end

    def to_s
      source_range.source
    end

    def inspect
      to_s.inspect
    end

    private

    def offset_range(range, begin_offset = 0, end_offset = 0)
      Parser::Source::Range.new(range.source_buffer,
                                range.begin_pos + begin_offset,
                                range.begin_pos + end_offset)
    end

    def parse_cop_names(directive_match)
      if all_cops?
        @cop_names = all_cop_names
        @cop_name_ranges = nil
      else
        cops_string = directive_match[:cops_string]
        cops_string_offset = directive_match.offset(:cops_string)
        cops_string_range = offset_range(comment_range, *cops_string_offset)

        @cop_names, @cop_name_ranges = extract_cops(cops_string,
                                                    cops_string_range)
      end

      @cop_names.freeze
      @cop_name_ranges.freeze
    end

    def extract_cops(cops_string, cops_string_range)
      cop_names = []
      cop_name_ranges = {}
      cops_string.scan(Regexp.new(COP_NAME_PATTERN)) do
        match = Regexp.last_match

        cop_name = qualified_cop_name(match.to_s)
        cop_names <<= cop_name
        cop_name_ranges[cop_name] = offset_range(cops_string_range,
                                                 *match.offset(0))
      end
      [cop_names, cop_name_ranges]
    end

    def qualified_cop_name(cop_name)
      Cop::Cop.qualified_cop_name(cop_name, source_range.source_buffer.name)
    end

    def all_cop_names
      Cop::Cop.registry.names - [UNNEEDED_DISABLE]
    end
  end
end
