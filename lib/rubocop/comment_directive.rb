# frozen_string_literal: true

require 'set'

module RuboCop
  # This class represents a single a `rubocop:*` comment directive.
  class CommentDirective
    UNNEEDED_DISABLE = 'Lint/UnneededDisable'.freeze

    # The available keywords to come after `# rubocop:`.
    KEYWORDS = %i[disable enable todo end_todo].freeze

    KEYWORD_PATTERN = "(?<keyword>#{KEYWORDS.join('|')})\\b".freeze
    COP_NAME_PATTERN = '([A-Z]\w+/)?(?:[A-Z]\w+)'.freeze
    COP_NAMES_PATTERN = "(?:#{COP_NAME_PATTERN} , )*#{COP_NAME_PATTERN}".freeze
    COPS_PATTERN = "(?<cops_string>all|#{COP_NAMES_PATTERN})".freeze

    COMMENT_DIRECTIVE_REGEXP = Regexp.new(
      "# rubocop : #{KEYWORD_PATTERN} #{COPS_PATTERN}".gsub(' ', '\s*')
    )

    # Yields a new CommentDirective for each rubocop directive in the given
    # Parser::Source::Comment, or returns an Enumerator if no block is given.
    def self.each_from_comment(comment)
      return enum_for(:each_from_comment) unless block_given?
      return unless comment

      open_keywords_seen = Set.new
      comment.text.scan(COMMENT_DIRECTIVE_REGEXP) do
        directive = new(comment, Regexp.last_match)

        # Allow only one of each type of directive per line.
        #
        # I.e. you can't have multiple rubocop:disables or a rubocop:disable
        # followed by a rubocop:enable on one line, but you *can* have
        # rubocop:disable followed by rubocop:todo on the same line.
        next if open_keywords_seen.include?(directive.open_keyword)

        open_keywords_seen << directive.open_keyword
        yield directive
      end
      nil
    end

    def self.exists_in?(comment)
      each_from_comment(comment) { return true }
      false
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

    def type
      case keyword
      when :disable, :todo then :open
      when :enable, :end_todo then :close
      end
    end

    def open_keyword
      case keyword
      when :disable, :enable then :disable
      when :todo, :end_todo then :todo
      end
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
