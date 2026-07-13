# frozen_string_literal: true

# Narrated customer-discovery climb for one assumption, then Lean Canvas PassRatio.
#
#   ruby -Ilib examples/validate_lean_canvas.rb

require "kalok/evidence"

# Local mutable assumption (Data.define freezes evidence_items).
class DemoAssumption
  attr_accessor :external_id, :text, :risk, :status, :linked_to, :evidence_items

  def initialize(external_id:, text: "", risk: "high", status: "untested", linked_to: [], evidence_items: [])
    @external_id = external_id
    @text = text
    @risk = risk
    @status = status
    @linked_to = Array(linked_to)
    @evidence_items = Array(evidence_items)
  end
end

module Demo
  module_function

  def item(kind:, criterion_id:, signal: "support", summary: nil, **extra)
    Kalok::Evidence::EvidenceItem.new(
      kind: kind,
      criterion_id: criterion_id,
      evidence_signal: signal,
      criterion_status: signal == "support" ? "validated" : "invalidated",
      occurred_on: Date.today,
      summary: summary || "#{kind} on #{criterion_id}",
      detail_data: extra.transform_keys(&:to_s)
    )
  end

  def interviews(n, criterion_id)
    Array.new(n) { |i| item(kind: "interview", criterion_id: criterion_id, summary: "interview #{i + 1}") }
  end

  def show_tier(label, assumption)
    result = Kalok::Evidence::Tier.for_assumption(assumption)
    puts "  [#{label}] engine=E-#{result.tier} display=#{result.display_tier} (#{result.label})"
    puts "           criterion=#{result.criterion_id.inspect}  hint=#{result.next_hint}"
  end
end

puts "=" * 72
puts "Kalok Evidence System — customer discovery climb (one assumption)"
puts "=" * 72
puts

pain = DemoAssumption.new(
  external_id: "a_pain",
  text: "Ops managers waste 8+ hours/week reconciling inventory across tools",
  risk: "high",
  status: "untested",
  linked_to: ["canvas.problem"],
  evidence_items: []
)

puts "Assumption: #{pain.text}"
puts "Criterion: inventory_pain"
puts

Demo.show_tier("E-0 empty", pain)

pain.evidence_items = Demo.interviews(1, "inventory_pain")
Demo.show_tier("1 interview", pain)

pain.evidence_items = Demo.interviews(3, "inventory_pain")
Demo.show_tier("3 interviews → Emerging", pain)

pain.evidence_items = Demo.interviews(5, "inventory_pain")
Demo.show_tier("5 interviews → Heard (E-1)", pain)

pain.evidence_items = Demo.interviews(5, "inventory_pain") + [
  Demo.item(kind: "behavioral", criterion_id: "inventory_pain", summary: "demo: 6 managers completed workflow")
]
Demo.show_tier("Heard + behavioral → Observed (E-2)", pain)

pain.evidence_items = Demo.interviews(5, "inventory_pain") + [
  Demo.item(kind: "behavioral", criterion_id: "inventory_pain", summary: "demo booked"),
  Demo.item(kind: "payment", criterion_id: "inventory_pain", summary: "deposit 1"),
  Demo.item(kind: "payment", criterion_id: "inventory_pain", summary: "deposit 2"),
  Demo.item(kind: "payment", criterion_id: "inventory_pain", summary: "deposit 3")
]
Demo.show_tier("Observed + 3 payments → Committed (E-3)", pain)

pain.evidence_items = Demo.interviews(5, "inventory_pain") + [
  Demo.item(kind: "behavioral", criterion_id: "inventory_pain", summary: "demo booked"),
  Demo.item(kind: "payment", criterion_id: "inventory_pain", summary: "deposit 1"),
  Demo.item(kind: "payment", criterion_id: "inventory_pain", summary: "deposit 2"),
  Demo.item(kind: "payment", criterion_id: "inventory_pain", summary: "deposit 3"),
  Demo.item(kind: "retention", criterion_id: "inventory_pain", summary: "still active", retention_days: 30)
]
Demo.show_tier("Committed + 30d retention → Sustained (E-4)", pain)

puts
puts "=" * 72
puts "Lean Canvas PassRatio — tiny B2B startup"
puts "=" * 72
puts

segment = DemoAssumption.new(
  external_id: "a_segment",
  text: "Mid-market wholesale ops teams are the beachhead",
  risk: "medium",
  status: "untested",
  linked_to: ["canvas.customer_segments"],
  evidence_items: Demo.interviews(5, "segment")
)

uvp = DemoAssumption.new(
  external_id: "a_uvp",
  text: "One source of truth beats spreadsheet stitching",
  risk: "high",
  status: "untested",
  linked_to: ["canvas.value_proposition"],
  evidence_items: Demo.interviews(5, "uvp") + [
    Demo.item(kind: "behavioral", criterion_id: "uvp", summary: "waitlist: 18 emails")
  ]
)

revenue = DemoAssumption.new(
  external_id: "a_revenue",
  text: "Teams will pay $400/mo for reconciliation automation",
  risk: "high",
  status: "untested",
  linked_to: ["canvas.revenue_streams"],
  evidence_items: Demo.interviews(5, "price")
)

abandoned = DemoAssumption.new(
  external_id: "a_old",
  text: "Abandoned channel myth",
  risk: "low",
  status: "abandon",
  linked_to: ["canvas.channels"],
  evidence_items: Demo.interviews(5, "channel")
)

startup = Kalok::Evidence::Startup.new(
  assumption_records: [pain, segment, uvp, revenue, abandoned]
)

result = Kalok::Evidence::PassRatio.call(startup)
interesting = %w[problem customer_segments value_proposition revenue_streams channels]
result[:blocks].each do |block|
  next if block.needed.zero? && !interesting.include?(block.block)

  min = "E-#{block.min_tier} (#{block.min_label})"
  puts format("%-20s  min=%-22s  %s", block.block, min, block.ratio_label)
  puts "  → #{block.next_hint}"
end

puts
puts "(Abandoned assumptions are excluded from needed. PassRatio uses integer engine tier only.)"
