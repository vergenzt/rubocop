# frozen_string_literal: true

module RuboCop
  module Cop
    # This module encapsulates the logic for autocorrect behavior for a cop.
    module AutocorrectLogic
      # flow chart:
      #
      #       [
      def correct(node, location = nil)
        # unavailable
        return :unsupported unless correctable?
        # available but not activated
        return :uncorrected unless autocorrect?

        correction = if should_disable?
                       disable_offense(node, location)
                     else
                       autocorrect(node)
                     end

        return :uncorrected unless correction
        @corrections << correction
        :corrected
      end

      def correctable?
        support_autocorrect? || disable_requested?
      end

      def autocorrect?
        autocorrect_requested? && correctable? && autocorrect_enabled?
      end

      def autocorrect_requested?
        @options.fetch(:auto_correct, false)
      end

      def support_autocorrect?
        respond_to?(:autocorrect, true)
      end

      def autocorrect_enabled?
        # allow turning off autocorrect on a cop by cop basis
        return true unless cop_config
        cop_config['AutoCorrect'] != false
      end

      def disable_requested?
        return false if cop_name == CommentConfig::UNNEEDED_DISABLE
        disable_uncorrectable? || disable_all?
      end

      def disable_uncorrectable?
        @options[:disable_uncorrectable] == true
      end

      def disable_all?
        @options[:disable_all] == true
      end

      def should_disable?
        disable_all? || (!support_autocorrect? && disable_uncorrectable?)
      end

      def disable_offense(node, location)
        range = location || node.source_range
        if end_of_line_editable?(range)
          disable_offense_at_end_of_line(range)
        else
          # Don't attempt to do multiline disables/enables for now because we'd
          # need to find an end-of-line that isn't in a string literal, and that
          # could end up being far away from the site of the offense. Eventually
          # we could try this, but for now we just don't attempt to correct.
          nil
        end
      end

      private

      def disable_offense_at_end_of_line(range)
        lambda do |corrector|
          first_line = range_by_whole_lines(range.begin)
          corrector.insert_after(first_line, " # rubocop:disable #{cop_name}")
        end
      end

      #def disable_offense_before_and_after(range)
      #  lambda do |corrector|
      #    range = range_by_whole_lines(range.begin, include_final_newline: true)
      #    leading_whitespace = range.source_line[/^\s*/]
      #
      #    corrector.insert_before(range, "#{leading_whitespace}# rubocop:disable #{cop_name}\n")
      #    corrector.insert_after(range,  "#{leading_whitespace}# rubocop:enable #{cop_name}\n")
      #  end
      #end

      def end_of_line_editable?(range)
        return true if !processed_source.ast

        end_of_line = range_by_whole_lines(range).end
        string_nodes = processed_source.ast.each_node(:str)
        string_nodes.none? do |node|
          node.source_range.overlaps?(end_of_line)
        end
      end
    end
  end
end
