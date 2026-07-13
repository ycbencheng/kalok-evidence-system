# frozen_string_literal: true

# Rule-gated evidence ladder (E-0…E-4). No LLM. Exact criterion_id match only.
# display_tier may be 0.5 (Emerging) while engine tier stays 0 — never passes a block.
module Kalok
  module Evidence
    class Tier
      LABELS = {
        0 => "Untested",
        0.5 => "Emerging",
        1 => "Heard",
        2 => "Observed",
        3 => "Committed",
        4 => "Sustained"
      }.freeze

      EMERGENT_MIN = 2
      INTERVIEW_THRESHOLD = 5
      PAYMENT_THRESHOLD = 3
      CONFLICT_RESOLVE_INTERVIEWS = 2
      RETENTION_DAYS = 30

      TIER_KINDS = {
        2 => %w[behavioral landing_page_result].freeze,
        3 => %w[payment].freeze,
        4 => %w[retention].freeze
      }.freeze

      Result = Data.define(
        :tier,
        :display_tier,
        :sub_status,
        :label,
        :criterion_id,
        :capped_by_contradiction,
        :interviews_toward_e1,
        :next_hint,
        :basis
      )

      def self.for_assumption(assumption, as_of: Date.today)
        new(assumption, as_of: as_of).call
      end

      def initialize(assumption, as_of: Date.today)
        @assumption = assumption
        @as_of = as_of
      end

      def call
        items = Array(@assumption.evidence_items)
        by_criterion = items.group_by { |item| criterion_id_for(item) }
        assigned = by_criterion.reject { |k, _| k.nil? || k == "" }
        unassigned_count = Array(by_criterion[nil]).size + Array(by_criterion[""]).size

        if assigned.empty?
          return result(
            tier: 0,
            display_tier: 0,
            sub_status: nil,
            criterion_id: nil,
            capped: false,
            interviews_toward_e1: 0,
            next_hint: empty_assignment_hint(items.size, unassigned_count),
            basis: { unassigned_count: unassigned_count }
          )
        end

        per_criterion = assigned.map { |cid, group| evaluate_criterion(cid, group) }
        best = per_criterion.max_by { |row| [row[:tier], row[:display_tier], row[:interviews_toward_e1]] }
        any_conflict = per_criterion.any? { |row| row[:capped_by_contradiction] }

        tier = best[:tier]
        tier = [tier, 1].min if any_conflict

        display_tier, sub_status = display_for(
          tier: tier,
          interview_count: best[:interview_count],
          supporting_interviews: best[:supporting_interviews],
          behavioral_present: best[:behavioral_present],
          conflict: any_conflict
        )

        result(
          tier: tier,
          display_tier: display_tier,
          sub_status: sub_status,
          criterion_id: best[:criterion_id],
          capped: any_conflict,
          interviews_toward_e1: best[:interviews_toward_e1],
          next_hint: next_hint_for(
            tier: tier,
            display_tier: display_tier,
            sub_status: sub_status,
            best: best,
            any_conflict: any_conflict
          ),
          basis: {
            criteria: per_criterion,
            unassigned_count: unassigned_count
          }
        )
      end

      private

      def empty_assignment_hint(total_count, unassigned_count)
        if total_count.zero?
          "No customer evidence yet. Run an experiment or log an interview."
        elsif unassigned_count.positive?
          n = unassigned_count
          "#{n} evidence item#{n == 1 ? '' : 's'} on file without a confirmed criterion — confirm a criterion so they count on the ladder."
        else
          "Confirm a criterion on evidence, then collect customer signal."
        end
      end

      def result(tier:, display_tier:, sub_status:, criterion_id:, capped:, interviews_toward_e1:, next_hint:, basis:)
        Result.new(
          tier: tier,
          display_tier: display_tier,
          sub_status: sub_status,
          label: LABELS.fetch(display_tier),
          criterion_id: criterion_id,
          capped_by_contradiction: capped,
          interviews_toward_e1: interviews_toward_e1,
          next_hint: next_hint,
          basis: basis
        )
      end

      def evaluate_criterion(criterion_id, items)
        signals = items.filter_map { |item| evidence_signal_for(item) }
        support = signals.count("support")
        oppose = signals.count("oppose")
        conflict = support.positive? && oppose.positive?

        interviews = items.select { |item| item.kind == "interview" && present?(criterion_id_for(item)) }
        supporting_interviews = interviews.count { |item| evidence_signal_for(item) == "support" }
        interview_count = supporting_interviews

        behavioral_present = items.any? { |item| TIER_KINDS[2].include?(item.kind) }
        payment_count = items.count { |item| TIER_KINDS[3].include?(item.kind) }
        retention_ok = items.any? { |item| retention_qualifies?(item) }

        raw_tier = 0
        raw_tier = 1 if interview_count >= INTERVIEW_THRESHOLD && !conflict

        # Cumulative gates — behavioral/payment/retention cannot skip the interview floor
        if !conflict && raw_tier >= 1
          raw_tier = 2 if behavioral_present
          raw_tier = 3 if raw_tier >= 2 && payment_count >= PAYMENT_THRESHOLD
          raw_tier = 4 if raw_tier >= 3 && retention_ok
        end

        tier = conflict ? [raw_tier, 1].min : raw_tier
        # Conflict with any supporting interviews still allows showing E-1 as "heard but conflicted"
        tier = 1 if conflict && interview_count.positive? && tier < 1

        {
          criterion_id: criterion_id,
          tier: tier,
          display_tier: nil,
          capped_by_contradiction: conflict,
          interviews_toward_e1: [interview_count, INTERVIEW_THRESHOLD].min,
          interview_count: interview_count,
          supporting_interviews: supporting_interviews,
          behavioral_present: behavioral_present,
          payment_count: payment_count,
          support_count: support,
          oppose_count: oppose,
          resolve_interviews_needed: conflict ? CONFLICT_RESOLVE_INTERVIEWS : 0
        }
      end

      def display_for(tier:, interview_count:, supporting_interviews:, behavioral_present:, conflict:)
        count = supporting_interviews.to_i

        if conflict
          return [[tier, 1].min, nil]
        end

        if tier >= 1
          sub = if tier == 1 && !behavioral_present
            "behavioral_pending"
          else
            nil
          end
          return [tier, sub]
        end

        if behavioral_present && count < INTERVIEW_THRESHOLD
          display = count >= EMERGENT_MIN ? 0.5 : 0
          return [display, "interviews_pending"]
        end

        if count >= EMERGENT_MIN
          return [0.5, "emergent"]
        end

        [0, nil]
      end

      def next_hint_for(tier:, display_tier:, sub_status:, best:, any_conflict:)
        if any_conflict
          n = best[:resolve_interviews_needed] || CONFLICT_RESOLVE_INTERVIEWS
          return "Conflicting signal detected — #{n} more interviews needed to resolve."
        end

        count = best[:interview_count].to_i
        needed = INTERVIEW_THRESHOLD - count

        case sub_status
        when "emergent"
          return "Emerging: #{count}/#{INTERVIEW_THRESHOLD} supporting interviews on criterion #{best[:criterion_id]} — need #{needed} more to reach Heard."
        when "interviews_pending"
          return "Behavioral complete — need #{needed} more supporting interview#{needed == 1 ? '' : 's'} on criterion #{best[:criterion_id]} to unlock Observed."
        when "behavioral_pending"
          return "Heard — run a behavioral test (signups, demos, time-on-task) to promote to Observed."
        end

        case tier
        when 0
          if needed.positive? && count.positive?
            "E-0: need #{needed} more supporting interview#{needed == 1 ? '' : 's'} on criterion #{best[:criterion_id]} to reach E-1."
          elsif needed.positive?
            "E-0: need #{INTERVIEW_THRESHOLD} supporting interviews on criterion #{best[:criterion_id]} to reach E-1."
          else
            "E-0: assign interview evidence to a criterion to start climbing."
          end
        when 1
          "E-1 Heard: run a behavioral test (signups, demos, time-on-task) to reach E-2."
        when 2
          payments = best[:payment_count].to_i
          remaining = PAYMENT_THRESHOLD - payments
          if remaining.positive?
            "E-2 Observed: need #{remaining} more payment#{remaining == 1 ? '' : 's'} (#{payments}/#{PAYMENT_THRESHOLD}) to reach E-3."
          else
            "E-2 Observed: seek payment, contract, or non-refundable deposit to reach E-3."
          end
        when 3
          "E-3 Committed: confirm repeat usage / retention over #{RETENTION_DAYS}+ days to reach E-4."
        else
          "E-4 Sustained: this criterion is at the top of the ladder."
        end
      end

      def criterion_id_for(item)
        explicit = if item.respond_to?(:criterion_id) && present?(item.criterion_id)
          item.criterion_id
        else
          detail = item.respond_to?(:detail_data) ? item.detail_data : {}
          detail = {} unless detail.is_a?(Hash)
          val = detail["criterion_id"].to_s
          present?(val) ? val : nil
        end
        return explicit if present?(explicit)

        kind = item.respond_to?(:kind) ? item.kind.to_s : nil
        return "default" if present?(kind) && kind != "interview" && kind != "other"

        nil
      end

      def evidence_signal_for(item)
        if item.respond_to?(:evidence_signal) && present?(item.evidence_signal)
          return item.evidence_signal
        end

        detail = item.respond_to?(:detail_data) ? item.detail_data : {}
        detail = {} unless detail.is_a?(Hash)
        explicit = detail["evidence_signal"].to_s
        return explicit if present?(explicit) && %w[support oppose].include?(explicit)

        status = if item.respond_to?(:criterion_status) && present?(item.criterion_status)
          item.criterion_status
        else
          detail["criterion_status"]
        end

        case status
        when "validated" then "support"
        when "invalidated" then "oppose"
        else nil
        end
      end

      def retention_qualifies?(item)
        return false unless item.kind == "retention"

        detail = item.respond_to?(:detail_data) ? item.detail_data : {}
        detail = {} unless detail.is_a?(Hash)
        days = detail["retention_days"].to_i
        return true if days >= RETENTION_DAYS

        return false if blank?(item.occurred_on)

        (@as_of - item.occurred_on).to_i >= RETENTION_DAYS
      end

      def present?(value)
        !blank?(value)
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?) || (value.is_a?(String) && value.strip.empty?)
      end
    end
  end
end
