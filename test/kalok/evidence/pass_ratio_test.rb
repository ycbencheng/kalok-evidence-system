# frozen_string_literal: true

require "test_helper"

class Kalok::Evidence::PassRatioTest < Minitest::Test
  def setup
    @assumptions = []
    @startup = Kalok::Evidence::Startup.new(assumption_records: @assumptions)
  end

  def test_block_from_linked_path_extracts_canvas_fields
    assert_equal "problem", Kalok::Evidence::CanvasMinimums.block_from_linked_path("canvas.problem")
    assert_equal "channels", Kalok::Evidence::CanvasMinimums.block_from_linked_path("canvas.channels[ch1]")
    assert_nil Kalok::Evidence::CanvasMinimums.block_from_linked_path("diagnosis.market")
  end

  def test_needed_set_includes_all_non_abandoned_linked_assumptions_regardless_of_risk
    high = ensure_assumption("a_high", risk: "high", linked_to: ["canvas.problem"], text: "High risk pain")
    low = ensure_assumption("a_low", risk: "low", linked_to: ["canvas.problem"], text: "Low risk channel myth")

    5.times { |i| add_interview(high, "pain", "h#{i}") }

    result = Kalok::Evidence::PassRatio.call(@startup)
    problem = result[:blocks].find { |b| b.block == "problem" }

    assert_equal 1, problem.min_tier
    assert_equal 2, problem.needed
    assert_equal 1, problem.passed
    assert_equal "1/2", problem.ratio_label
    assert_equal 1, problem.remaining.size
    assert_equal low.external_id, problem.remaining.first.external_id
    assert_nil problem.remaining.first.sub_status
    assert_includes problem.next_hint, "E-1"
  end

  def test_abandoned_assumptions_are_excluded_from_needed
    active = ensure_assumption("a_active", risk: "high", linked_to: ["canvas.solution"], text: "Active")
    gone = ensure_assumption("a_gone", risk: "high", linked_to: ["canvas.solution"], text: "Gone", status: "abandon")
    5.times { |i| add_interview(active, "sol", "i#{i}") }
    add_item(active, kind: "behavioral", criterion_id: "sol", summary: "used demo")
    5.times { |i| add_interview(gone, "sol", "x#{i}") }
    add_item(gone, kind: "behavioral", criterion_id: "sol", summary: "ignored")

    result = Kalok::Evidence::PassRatio.call(@startup)
    solution = result[:blocks].find { |b| b.block == "solution" }

    assert_equal 1, solution.needed
    assert_equal 1, solution.passed
    assert_empty solution.remaining
  end

  def test_revenue_streams_requires_e3_so_interviews_alone_do_not_pass
    a = ensure_assumption("a_rev", risk: "high", linked_to: ["canvas.revenue_streams"], text: "People will pay")
    5.times { |i| add_interview(a, "price", "r#{i}") }

    result = Kalok::Evidence::PassRatio.call(@startup)
    revenue = result[:blocks].find { |b| b.block == "revenue_streams" }

    assert_equal 3, revenue.min_tier
    assert_equal 0, revenue.passed
    assert_equal 1, revenue.needed
    assert_includes revenue.next_hint, "E-3"
  end

  def test_payment_evidence_passes_revenue_streams
    a = ensure_assumption("a_rev2", risk: "high", linked_to: ["canvas.revenue_streams"], text: "Paid")
    5.times { |i| add_interview(a, "price", "r#{i}") }
    add_item(a, kind: "behavioral", criterion_id: "price", summary: "demo booked")
    3.times { |i| add_item(a, kind: "payment", criterion_id: "price", summary: "deposit #{i}") }

    result = Kalok::Evidence::PassRatio.call(@startup)
    revenue = result[:blocks].find { |b| b.block == "revenue_streams" }

    assert_equal 1, revenue.passed
    assert_equal 1, revenue.needed
  end

  def test_empty_block_reports_zero_needed_with_onboarding_hint
    result = Kalok::Evidence::PassRatio.call(@startup)
    unfair = result[:blocks].find { |b| b.block == "unfair_advantage" }

    assert_equal 0, unfair.needed
    assert_equal "0/0", unfair.ratio_label
    assert_includes unfair.next_hint, "no linked assumptions"
  end

  private

  def ensure_assumption(external_id, risk:, linked_to:, text:, status: "untested")
    record = MutableAssumption.new(
      external_id: external_id,
      text: text,
      risk: risk,
      status: status,
      linked_to: linked_to,
      evidence_items: []
    )
    @assumptions << record
    record
  end

  def add_interview(assumption, criterion_id, summary)
    add_item(assumption, kind: "interview", criterion_id: criterion_id, summary: summary, signal: "support")
  end

  def add_item(assumption, kind:, criterion_id:, summary:, signal: "support")
    assumption.evidence_items << Kalok::Evidence::EvidenceItem.new(
      kind: kind,
      summary: summary,
      occurred_on: Date.today,
      criterion_id: criterion_id,
      evidence_signal: signal,
      criterion_status: "validated",
      detail_data: {
        "criterion_id" => criterion_id,
        "evidence_signal" => signal,
        "criterion_status" => "validated"
      }
    )
  end
end
