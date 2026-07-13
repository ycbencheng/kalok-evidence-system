# frozen_string_literal: true

require "test_helper"

class Kalok::Evidence::TierTest < Minitest::Test
  def setup
    @assumption = MutableAssumption.new(external_id: "a1", text: "Pain is real")
  end

  def test_e0_when_no_evidence
    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 0, result.tier
    assert_equal 0, result.display_tier
    assert_equal "Untested", result.label
    assert_nil result.sub_status
    refute result.capped_by_contradiction
  end

  def test_e0_when_interviews_lack_criterion_id
    5.times { |i| add_interview(summary: "note #{i}", criterion_id: nil, signal: "support") }

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 0, result.tier
    assert_equal 0, result.display_tier
    assert_includes result.next_hint, "criterion"
  end

  def test_0_1_supporting_interviews_stay_untested
    add_interview(summary: "note 0", criterion_id: "pain", signal: "support")

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 0, result.tier
    assert_equal 0, result.display_tier
    assert_equal "Untested", result.label
    assert_nil result.sub_status
  end

  def test_2_4_supporting_interviews_are_display_only_emerging
    3.times { |i| add_interview(summary: "note #{i}", criterion_id: "pain", signal: "support") }

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 0, result.tier
    assert_equal 0.5, result.display_tier
    assert_equal "Emerging", result.label
    assert_equal "emergent", result.sub_status
    assert_equal "pain", result.criterion_id
    assert_includes result.next_hint, "Emerging"
    assert_includes result.next_hint, "2 more"
  end

  def test_oppose_interviews_do_not_count_toward_floors
    4.times { |i| add_interview(summary: "yes #{i}", criterion_id: "pain", signal: "support") }
    add_interview(summary: "no", criterion_id: "pain", signal: "oppose")

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert result.capped_by_contradiction
    assert_equal 1, result.tier
  end

  def test_interviews_on_different_criterion_ids_do_not_combine_for_e1
    3.times { |i| add_interview(summary: "a#{i}", criterion_id: "pain", signal: "support") }
    2.times { |i| add_interview(summary: "b#{i}", criterion_id: "acquisition", signal: "support") }

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 0, result.tier
    assert_equal 0.5, result.display_tier
  end

  def test_e1_with_5_supporting_interviews_on_same_criterion_id
    5.times { |i| add_interview(summary: "note #{i}", criterion_id: "pain", signal: "support") }

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 1, result.tier
    assert_equal 1, result.display_tier
    assert_equal "Heard", result.label
    assert_equal "behavioral_pending", result.sub_status
    assert_equal "pain", result.criterion_id
    refute result.capped_by_contradiction
    assert_includes result.next_hint, "behavioral"
  end

  def test_behavioral_alone_stays_below_heard_with_interviews_pending
    add_item(kind: "behavioral", summary: "5 signups", criterion_id: "uvp", signal: "support")

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 0, result.tier
    assert_equal 0, result.display_tier
    assert_equal "interviews_pending", result.sub_status
    assert_includes result.next_hint, "Behavioral complete"
  end

  def test_behavioral_with_2_4_interviews_is_emerging_interviews_pending
    3.times { |i| add_interview(summary: "n#{i}", criterion_id: "uvp", signal: "support") }
    add_item(kind: "behavioral", summary: "5 signups", criterion_id: "uvp", signal: "support")

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 0, result.tier
    assert_equal 0.5, result.display_tier
    assert_equal "interviews_pending", result.sub_status
  end

  def test_landing_page_result_alone_does_not_reach_observed
    add_item(kind: "landing_page_result", summary: "12 emails", criterion_id: "channel", signal: "support")

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 0, result.tier
    assert_equal "interviews_pending", result.sub_status
  end

  def test_e2_requires_heard_plus_behavioral
    5.times { |i| add_interview(summary: "note #{i}", criterion_id: "uvp", signal: "support") }
    add_item(kind: "behavioral", summary: "5 signups", criterion_id: "uvp", signal: "support")

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 2, result.tier
    assert_equal 2, result.display_tier
    assert_equal "Observed", result.label
    assert_nil result.sub_status
  end

  def test_payment_alone_does_not_reach_committed
    add_item(kind: "payment", summary: "deposit received", criterion_id: "revenue", signal: "support")

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 0, result.tier
  end

  def test_e2_plus_1_2_payments_stays_observed
    5.times { |i| add_interview(summary: "note #{i}", criterion_id: "revenue", signal: "support") }
    add_item(kind: "behavioral", summary: "demo", criterion_id: "revenue", signal: "support")
    2.times { |i| add_item(kind: "payment", summary: "pay #{i}", criterion_id: "revenue", signal: "support") }

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 2, result.tier
    assert_includes result.next_hint, "1 more payment"
  end

  def test_e3_with_observed_plus_3_payments
    5.times { |i| add_interview(summary: "note #{i}", criterion_id: "revenue", signal: "support") }
    add_item(kind: "behavioral", summary: "demo", criterion_id: "revenue", signal: "support")
    3.times { |i| add_item(kind: "payment", summary: "pay #{i}", criterion_id: "revenue", signal: "support") }

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 3, result.tier
    assert_equal "Committed", result.label
  end

  def test_e4_with_committed_plus_30_day_retention
    5.times { |i| add_interview(summary: "note #{i}", criterion_id: "advantage", signal: "support") }
    add_item(kind: "behavioral", summary: "demo", criterion_id: "advantage", signal: "support")
    3.times { |i| add_item(kind: "payment", summary: "pay #{i}", criterion_id: "advantage", signal: "support") }
    add_item(
      kind: "retention",
      summary: "still active",
      criterion_id: "advantage",
      signal: "support",
      detail_extra: { "retention_days" => 30 }
    )

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 4, result.tier
    assert_equal "Sustained", result.label
  end

  def test_retention_under_30_days_does_not_reach_e4
    5.times { |i| add_interview(summary: "note #{i}", criterion_id: "advantage", signal: "support") }
    add_item(kind: "behavioral", summary: "demo", criterion_id: "advantage", signal: "support")
    3.times { |i| add_item(kind: "payment", summary: "pay #{i}", criterion_id: "advantage", signal: "support") }
    add_item(
      kind: "retention",
      summary: "week one",
      criterion_id: "advantage",
      signal: "support",
      detail_extra: { "retention_days" => 7 },
      occurred_on: Date.today
    )

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 3, result.tier
  end

  def test_contradiction_caps_at_e1_and_sets_resolve_hint
    5.times { |i| add_interview(summary: "loves price #{i}", criterion_id: "price", signal: "support") }
    add_interview(summary: "too expensive", criterion_id: "price", signal: "oppose")
    add_item(kind: "payment", summary: "paid", criterion_id: "price", signal: "support")

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 1, result.tier
    assert result.capped_by_contradiction
    assert_includes result.next_hint, "Conflicting signal"
    assert_includes result.next_hint, "2 more interviews"
  end

  def test_criterion_status_invalidated_maps_to_oppose_for_contradiction
    add_interview(summary: "yes", criterion_id: "pain", status: "validated")
    add_interview(summary: "no", criterion_id: "pain", status: "invalidated")

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert result.capped_by_contradiction
    assert_equal 1, result.tier
  end

  def test_higher_tier_wins_across_criteria_when_no_contradiction
    5.times { |i| add_interview(summary: "i#{i}", criterion_id: "pain", signal: "support") }
    5.times { |i| add_interview(summary: "r#{i}", criterion_id: "revenue", signal: "support") }
    add_item(kind: "behavioral", summary: "demo", criterion_id: "revenue", signal: "support")
    3.times { |i| add_item(kind: "payment", summary: "paid #{i}", criterion_id: "revenue", signal: "support") }

    result = Kalok::Evidence::Tier.for_assumption(@assumption)

    assert_equal 3, result.tier
    assert_equal "revenue", result.criterion_id
  end

  private

  def present?(value)
    !(value.nil? || (value.respond_to?(:empty?) && value.empty?) || (value.is_a?(String) && value.strip.empty?))
  end

  def add_interview(summary:, criterion_id:, signal: nil, status: nil)
    add_item(kind: "interview", summary: summary, criterion_id: criterion_id, signal: signal, status: status)
  end

  def add_item(kind:, summary:, criterion_id:, signal: nil, status: nil, detail_extra: {}, occurred_on: Date.today)
    detail = detail_extra.dup
    detail["criterion_id"] = criterion_id if present?(criterion_id)
    detail["evidence_signal"] = signal if present?(signal)
    detail["criterion_status"] = status if present?(status)

    @assumption.evidence_items << Kalok::Evidence::EvidenceItem.new(
      kind: kind,
      summary: summary,
      occurred_on: occurred_on,
      criterion_id: criterion_id,
      evidence_signal: signal,
      criterion_status: status,
      detail_data: detail
    )
  end
end
