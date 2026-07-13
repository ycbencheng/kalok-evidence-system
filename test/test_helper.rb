# frozen_string_literal: true

require "minitest/autorun"
require "date"
require "kalok/evidence"

# Mutable wrapper — Data.define freezes evidence_items, which makes golden tests awkward.
class MutableAssumption
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
