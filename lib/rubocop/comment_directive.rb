# frozen_string_literal: true

module RuboCop
  # This class represents a single a `rubocop:*` comment directive.
  class CommentDirective
    UNNEEDED_DISABLE = 'Lint/UnneededDisable'.freeze

    # The available keywords to come after `# rubocop:`.
    KEYWORDS = %i[disable enable].freeze

    KEYWORD_PATTERN = "(?<keyword>#{KEYWORDS.join('|')})\\b".freeze
    COP_NAME_PATTERN = '([A-Z]\w+/)?(?:[A-Z]\w+)'.freeze
    COP_NAMES_PATTERN = "(?:#{COP_NAME_PATTERN} , )*#{COP_NAME_PATTERN}".freeze
    COPS_PATTERN = "(?<cops_string>all|#{COP_NAMES_PATTERN})".freeze

    COMMENT_DIRECTIVE_REGEXP = Regexp.new(
      "# rubocop : #{KEYWORD_PATTERN} #{COPS_PATTERN}".gsub(' ', '\s*')
    )

    # Initializes a new CommentDirective if the provided Parser::Source::Comment
    # contains a directive. Returns nil if it does not.
    def self.from_comment(comment)
      return unless comment && comment.text =~ COMMENT_DIRECTIVE_REGEXP
      new(comment, Regexp.last_match)
    end

    def initialize(comment, match)
      @source_range = offset_range(comment.loc.expression, *match.offset(0))
      @keyword = match[:keyword].to_sym
      @all_cops = match[:cops_string] == 'all'
      @cop_names = parse_cop_names(match[:cops_string])
      freeze
    end

    attr_reader :source_range
    attr_reader :keyword
    attr_reader :all_cops
    attr_reader :cop_names

    alias all_cops? all_cops

    def line
      source_range.line
    end

    private

    def offset_range(range, begin_offset = 0, end_offset = 0)
      Parser::Source::Range.new(range.source_buffer,
                                range.begin_pos + begin_offset,
                                range.begin_pos + end_offset)
    end

    def parse_cop_names(cops_string)
      if all_cops?
        all_cop_names
      else
        cops_string.split(/\s*,\s*/).map do |name|
          Cop::Cop.qualified_cop_name(name, source_range.source_buffer.name)
        end
      end
    end

    def all_cop_names
      Cop::Cop.registry.names - [UNNEEDED_DISABLE]
    end
  end
end
