# frozen_string_literal: true

# Honest ratio: passed / needed per canvas block. Needed = all non-abandoned linked assumptions.
module Kalok
  module Evidence
    class PassRatio
      BlockResult = Data.define(
        :block,
        :min_tier,
        :min_label,
        :passed,
        :needed,
        :ratio_label,
        :assumptions,
        :remaining,
        :next_hint
      )

      AssumptionRow = Data.define(
        :external_id,
        :text,
        :risk,
        :status,
        :tier,
        :display_tier,
        :tier_label,
        :passes,
        :capped_by_contradiction,
        :sub_status,
        :next_hint,
        :linked_to
      )

      def self.call(startup, as_of: Date.today)
        new(startup, as_of: as_of).call
      end

      def initialize(startup, as_of: Date.today)
        @startup = startup
        @as_of = as_of
      end

      def call
        assumptions = Array(@startup.assumption_records).reject { |a| a.status.to_s == "abandon" }

        by_block = Hash.new { |h, k| h[k] = [] }

        assumptions.each do |assumption|
          blocks = Array(assumption.linked_to).filter_map { |path| CanvasMinimums.block_from_linked_path(path) }.uniq
          next if blocks.empty?

          tier_result = Tier.for_assumption(assumption, as_of: @as_of)
          blocks.each do |block|
            min = CanvasMinimums.min_tier_for(block)
            passes = tier_result.tier >= min
            row = AssumptionRow.new(
              external_id: assumption.external_id,
              text: assumption.text,
              risk: assumption.risk,
              status: assumption.status,
              tier: tier_result.tier,
              display_tier: tier_result.display_tier,
              tier_label: tier_result.label,
              passes: passes,
              capped_by_contradiction: tier_result.capped_by_contradiction,
              sub_status: tier_result.sub_status,
              next_hint: tier_result.next_hint,
              linked_to: Array(assumption.linked_to)
            )
            by_block[block] << row
          end
        end

        blocks = CanvasMinimums::BLOCKS.map do |block|
          rows = Array(by_block[block])
          min = CanvasMinimums.min_tier_for(block)
          passed = rows.count(&:passes)
          needed = rows.size
          remaining = rows.reject(&:passes)

          BlockResult.new(
            block: block,
            min_tier: min,
            min_label: Tier::LABELS.fetch(min),
            passed: passed,
            needed: needed,
            ratio_label: "#{passed}/#{needed}",
            assumptions: rows,
            remaining: remaining,
            next_hint: block_hint(block: block, min: min, remaining: remaining, needed: needed)
          )
        end

        { blocks: blocks }
      end

      private

      def block_hint(block:, min:, remaining:, needed:)
        label = block.to_s.tr("_", " ")
        min_label = Tier::LABELS.fetch(min)

        if needed.zero?
          return "#{label.capitalize}: no linked assumptions yet — add one to start tracking."
        end

        if remaining.empty?
          return "#{label.capitalize}: #{needed}/#{needed} at E-#{min} (#{min_label}) or above — block passes."
        end

        first = remaining.first
        display = first.display_tier
        display_text = display == 0.5 ? "0.5" : display.to_i.to_s
        "#{label.capitalize}: E-#{min} (#{min_label}) required · #{needed - remaining.size}/#{needed} pass. " \
          "Next: #{first.external_id} is E-#{display_text} — #{first.next_hint}"
      end
    end
  end
end
