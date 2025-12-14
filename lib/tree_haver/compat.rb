# frozen_string_literal: true

# Opt-in compatibility shim to satisfy code that expects `TreeSitter`
# When required, it maps TreeSitter constants to TreeHaver equivalents,
# but does not override if a real TreeSitter is already loaded.

unless defined?(::TreeSitter)
  module TreeSitter; end
  TreeSitter::Error = TreeHaver::Error
  TreeSitter::Parser = TreeHaver::Parser
  TreeSitter::Tree   = TreeHaver::Tree
  TreeSitter::Node   = TreeHaver::Node
  TreeSitter::Language = TreeHaver::Language
end
