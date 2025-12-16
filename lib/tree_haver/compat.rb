# frozen_string_literal: true

# Compatibility shim for code that expects TreeSitter constants
#
# When required, this file creates a TreeSitter module that maps to TreeHaver
# equivalents, allowing code written for ruby_tree_sitter to work with TreeHaver
# without modification.
#
# This shim is safe and idempotent:
# - If TreeSitter is already defined (real ruby_tree_sitter is loaded), this does nothing
# - If TreeSitter is not defined, it creates aliases to TreeHaver
#
# @example Using the compatibility shim
#   require "tree_haver/compat"
#
#   # Now code expecting TreeSitter will work
#   parser = TreeSitter::Parser.new  # Actually creates TreeHaver::Parser
#   tree = parser.parse(source)
#
# @note CRITICAL: Exception Hierarchy Incompatibility
#
#   ruby_tree_sitter v2+ exceptions inherit from Exception (not StandardError).
#   TreeHaver exceptions follow Ruby best practices and inherit from StandardError.
#
#   This means exception handling behaves DIFFERENTLY:
#
#   **ruby_tree_sitter v2+ (real):**
#     begin
#       TreeSitter::Language.load(...)
#     rescue => e  # Does NOT catch TreeSitter errors (they're Exception)
#       # Never reached for TreeSitter::TreeSitterError
#     end
#
#   **TreeHaver compat mode:**
#     require "tree_haver/compat"
#     begin
#       TreeSitter::Language.load(...)  # Actually TreeHaver
#     rescue => e  # DOES catch errors (they're StandardError)
#       # WILL be reached - DIFFERENT behavior!
#     end
#
#   To handle exceptions consistently:
#     - Catch TreeSitter::TreeSitterError explicitly (works with both)
#     - Or catch TreeHaver::NotAvailable when using TreeHaver directly
#
# @note This is an opt-in feature. Only require this file if you need compatibility
# @see TreeHaver The main module this aliases to

unless defined?(TreeSitter)
  # Compatibility module aliasing TreeHaver classes to TreeSitter
  #
  # @note Only defined if TreeSitter doesn't already exist
  module TreeSitter; end

  # @!parse
  #   module TreeSitter
  #     Error = TreeHaver::Error
  #     Parser = TreeHaver::Parser
  #     Tree = TreeHaver::Tree
  #     Node = TreeHaver::Node
  #     Language = TreeHaver::Language
  #   end

  TreeSitter::Error = TreeHaver::Error
  TreeSitter::Parser = TreeHaver::Parser
  TreeSitter::Tree = TreeHaver::Tree
  TreeSitter::Node = TreeHaver::Node
  TreeSitter::Language = TreeHaver::Language
end
