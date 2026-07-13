# frozen_string_literal: true

# Per-canvas-block minimum evidence tier required to "pass".
module Kalok
  module Evidence
    module CanvasMinimums
      # Canvas field => minimum tier (0–4)
      MINIMUMS = {
        "problem" => 1,
        "customer_segments" => 1,
        "value_proposition" => 2,
        "solution" => 2,
        "channels" => 2,
        "revenue_streams" => 3,
        "cost_structure" => 3,
        "key_metrics" => 2,
        "unfair_advantage" => 4
      }.freeze

      BLOCKS = MINIMUMS.keys.freeze

      module_function

      def min_tier_for(block)
        MINIMUMS[block.to_s]
      end

      def block_from_linked_path(path)
        path = path.to_s.strip
        return nil if path.empty?

        # canvas.problem | canvas.channels[ch1] | canvas.customer_segments[cs1]
        match = path.match(/\Acanvas\.([a-z_]+)(?:\[|\z)/)
        return nil unless match

        block = match[1]
        BLOCKS.include?(block) ? block : nil
      end
    end
  end
end
