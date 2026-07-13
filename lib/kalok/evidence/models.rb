# frozen_string_literal: true

module Kalok
  module Evidence
    # Thin POROs that duck-type the Kalok app's Assumption / EvidenceItem surfaces.
    EvidenceItem = Data.define(
      :kind,
      :criterion_id,
      :evidence_signal,
      :criterion_status,
      :occurred_on,
      :detail_data,
      :summary
    ) do
      def initialize(
        kind:,
        criterion_id: nil,
        evidence_signal: nil,
        criterion_status: nil,
        occurred_on: nil,
        detail_data: nil,
        summary: nil
      )
        detail = detail_data || {}
        detail = detail.transform_keys(&:to_s) if detail.respond_to?(:transform_keys)
        super(
          kind: kind.to_s,
          criterion_id: criterion_id,
          evidence_signal: evidence_signal,
          criterion_status: criterion_status,
          occurred_on: occurred_on,
          detail_data: detail,
          summary: summary
        )
      end
    end

    Assumption = Data.define(
      :external_id,
      :text,
      :risk,
      :status,
      :linked_to,
      :evidence_items
    ) do
      def initialize(
        external_id:,
        text: "",
        risk: "high",
        status: "untested",
        linked_to: [],
        evidence_items: []
      )
        super(
          external_id: external_id,
          text: text,
          risk: risk,
          status: status,
          linked_to: Array(linked_to),
          evidence_items: Array(evidence_items)
        )
      end
    end

    # Minimal stand-in for a Startup / workspace with assumption_records.
    Startup = Data.define(:assumption_records) do
      def initialize(assumption_records: [])
        super(assumption_records: Array(assumption_records))
      end
    end
  end
end
