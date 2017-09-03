# frozen_string_literal: true

module RuboCop
  module Cop
    module Lint
      # This cop detects instances of rubocop:disable comments that can be
      # removed without causing any offenses to be reported. It's implemented
      # as a cop in that it inherits from the Cop base class and calls
      # add_offense. The unusual part of its implementation is that it doesn't
      # have any on_* methods or an investigate method. This means that it
      # doesn't take part in the investigation phase when the other cops do
      # their work. Instead, it waits until it's called in a later stage of the
      # execution. The reason it can't be implemented as a normal cop is that
      # it depends on the results of all other cops to do its work.
      #
      # Note: Many aspects of this file should be refactored to consolidate
      # logic into `CommentDirective`.
      class UnneededDisable < Cop
        include NameSimilarity

        COP_NAME = 'Lint/UnneededDisable'.freeze

        def check(all_offenses, comment_config)
          offended_directive_cops = offended_directive_cops(all_offenses,
                                                            comment_config)

          relevant_directives = comment_config.directives.select do |directive|
            directive.keyword == :disable && enabled_line?(directive.line)
          end

          unoffended_directive_cops = relevant_directives.map do |directive|
            offended_cops = offended_directive_cops[directive]
            [directive, directive.cop_names - [COP_NAME] - offended_cops]
          end.to_h

          add_offenses(unoffended_directive_cops)
        end

        def autocorrect(args)
          lambda do |corrector|
            directive, unoffended_cop_names, this_cop_name = *args

            corrector.remove(
              if unoffended_cop_names.size == directive.cop_names.size
                directive_range_with_surrounding_space(directive)
              else
                cop_range = directive.cop_range(this_cop_name)
                cop_ranges = unoffended_cop_names.map do |cop_name|
                  directive.cop_range(cop_name)
                end
                directive_range_in_list(cop_range, cop_ranges)
              end
            )
          end
        end

        private

        def offended_directive_cops(all_offenses, comment_config)
          offended_directive_cops = Hash.new { |h, k| h[k] = [] }

          all_offenses.group_by(&:cop_name).each do |cop_name, offenses|
            disabled_ranges = comment_config.cop_disabled_line_ranges[cop_name]
            offenses.each do |offense|
              directive = assigned_directive(offense, disabled_ranges)
              offended_directive_cops[directive] <<= cop_name if directive
            end
          end

          offended_directive_cops
        end

        # Returns a directive to assign this offense to if the offense is
        # covered by a disabled range.
        def assigned_directive(offense, disabled_ranges)
          covering_ranges = disabled_ranges.select do |range|
            range.cover? offense.line
          end
          preferred_directive_from(covering_ranges.map(&:begin_directive))
        end

        def preferred_directive_from(covering_directives)
          covering_directives.min_by do |directive|
            [
              # first prefer "all" directives
              directive.all_cops ? 0 : 1,
              # then prefer directives declared first
              directive.line
            ]
          end
        end

        def add_offenses(unoffended_directive_cops)
          unoffended_directive_cops
            .sort_by { |directive, _cops| directive.source_range.begin_pos }
            .each do |directive, cops|
              if cops.size == directive.cop_names.size
                add_offense_for_entire_comment(directive, cops)
              elsif !cops.empty? && cops.size < directive.cop_names.size
                if directive.all_cops?
                  # Ignore. If a directive disables all cops and not all
                  # disables were unneeded, then leave it be. The directive
                  # isn't unneeded.
                else
                  add_offense_for_some_cops(directive, cops)
                end
              end
            end
        end

        def add_offense_for_entire_comment(directive, cop_names)
          description = if directive.all_cops?
                          'all cops'
                        else
                          cop_names.sort.map { |c| describe(c) }.join(', ')
                        end

          add_offense([directive, cop_names], directive.source_range,
                      "Unnecessary disabling of #{description}.")
        end

        def add_offense_for_some_cops(directive, cop_names)
          cop_names.each do |cop|
            add_offense([directive, cop_names, cop], directive.cop_range(cop),
                        "Unnecessary disabling of #{describe(cop)}.")
          end
        end

        def directive_range_with_surrounding_space(directive)
          # Eat the entire comment, the preceding space, and the preceding
          # newline if there is one.
          range = directive.source_range
          original_begin = range.begin_pos
          range = range_with_surrounding_space(range, :left, true)
          range = range_with_surrounding_space(range, :right,
                                               # Special for a comment that
                                               # begins the file: remove
                                               # the newline at the end.
                                               original_begin.zero?)
          range
        end

        def directive_range_in_list(range, ranges)
          # Is there any cop between this one and the end of the line, which
          # is NOT being removed?
          if ends_its_line?(ranges.last) && trailing_range?(ranges, range)
            # Eat the comma on the left.
            range = range_with_surrounding_space(range, :left)
            range = range_with_surrounding_comma(range, :left)
          end

          range = range_with_surrounding_comma(range, :right)
          # Eat following spaces up to EOL, but not the newline itself.
          range_with_surrounding_space(range, :right, false)
        end

        def cop_range_in_list(directive, cop_name)
          # Assumption: directive includes more than one cop. If it didn't, then
          # we'd be removing the entire directive, not just this cop.

          range = directive.cop_range(cop_name)
          if cop_name == directive.cop_names.first
            # If at beginning of list, eat the comma on the right.
            range = range_with_surrounding_space(range, :right)
            range = range_with_surrounding_comma(range, :right)
          else
            # Otherwise, eat the comma on the left.
            range = range_with_surrounding_comma(range, :left)
            range = range_with_surrounding_space(range, :left)
          end
          range
        end

        def trailing_range?(ranges, range)
          ranges
            .drop_while { |r| !r.equal?(range) }
            .each_cons(2)
            .map { |r1, r2| r1.end.join(r2.begin).source }
            .all? { |intervening| intervening =~ /\A\s*,\s*\Z/ }
        end

        def describe(cop)
          if all_cop_names.include?(cop)
            "`#{cop}`"
          else
            similar = find_similar_name(cop, [])
            if similar
              "`#{cop}` (did you mean `#{similar}`?)"
            else
              "`#{cop}` (unknown cop)"
            end
          end
        end

        def collect_variable_like_names(scope)
          all_cop_names.each { |name| scope << name }
        end

        def all_cop_names
          @all_cop_names ||= Cop.registry.names
        end
      end
    end
  end
end
