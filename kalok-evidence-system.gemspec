# frozen_string_literal: true

require_relative "lib/kalok/evidence/version"

Gem::Specification.new do |spec|
  spec.name          = "kalok-evidence-system"
  spec.version       = Kalok::Evidence::VERSION
  spec.authors       = ["Kalok"]
  spec.summary       = "Lean Canvas validation ladder — rule-gated evidence tiers E-0…E-4"
  spec.description   = "Portable PORO extraction of Kalok's evidence ladder: Tier, CanvasMinimums, PassRatio."
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]
end
