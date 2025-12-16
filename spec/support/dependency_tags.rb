# frozen_string_literal: true

# Dependency detection helpers for conditional test execution
#
# This module detects which optional dependencies are available and configures
# RSpec to skip tests that require unavailable dependencies.
#
# Usage in specs:
#   it "requires FFI", :ffi do
#     # This test only runs when FFI is available
#   end
#
#   it "requires ruby_tree_sitter", :mri_backend do
#     # This test only runs when ruby_tree_sitter gem is available
#   end
#
#   it "requires tree_stump", :rust_backend do
#     # This test only runs when tree_stump gem is available
#   end
#
#   it "requires JRuby", :jruby do
#     # This test only runs on JRuby
#   end
#
#   it "requires libtree-sitter", :libtree_sitter do
#     # This test only runs when libtree-sitter.so is loadable
#   end
#
#   it "requires a TOML grammar", :toml_grammar do
#     # This test only runs when a TOML grammar library is available
#   end
#
# Negated tags (for testing behavior when dependencies are NOT available):
#   it "only runs when ruby_tree_sitter is NOT available", :not_mri_backend do
#     # This test only runs when ruby_tree_sitter gem is NOT available
#   end

module TreeHaverDependencies
  class << self
    # Check if FFI backend is actually usable (live check, not memoized)
    #
    # This method attempts to actually use the FFI backend by loading a language.
    # This provides "live" validation of backend availability because:
    # - If FFI gem is missing, it will fail
    # - If MRI backend was used first, BackendConflict will be raised
    # - If libtree-sitter is missing, it will fail
    #
    # NOT MEMOIZED: Each call re-checks availability. This validates that
    # backend protection works correctly as tests run. FFI tests should run
    # first (via `rake spec` which runs ffi_specs then remaining_specs).
    #
    # For isolated FFI testing, use bin/rspec-ffi
    def ffi_available?
      # Try to actually use the FFI backend
      path = find_toml_grammar_path
      return false unless path && File.exist?(path)

      TreeHaver.with_backend(:ffi) do
        TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
      end
      true
    rescue TreeHaver::BackendConflict, TreeHaver::NotAvailable, LoadError
      false
    end

    # Check if ruby_tree_sitter gem is available (MRI backend)
    def mri_backend_available?
      return @mri_backend_available if defined?(@mri_backend_available)
      @mri_backend_available = begin
        require "ruby_tree_sitter"
        true
      rescue LoadError
        false
      end
    end

    # Check if tree_stump gem is available (Rust backend)
    def rust_backend_available?
      return @rust_backend_available if defined?(@rust_backend_available)
      @rust_backend_available = begin
        require "tree_stump"
        true
      rescue LoadError
        false
      end
    end

    # Check if running on JRuby
    def jruby?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
    end

    # Check if Java backend is available (requires JRuby + java-tree-sitter)
    def java_backend_available?
      return @java_backend_available if defined?(@java_backend_available)
      @java_backend_available = jruby? && TreeHaver::Backends::Java.available?
    end

    # Check if libtree-sitter runtime library is loadable
    def libtree_sitter_available?
      return @libtree_sitter_available if defined?(@libtree_sitter_available)
      @libtree_sitter_available = begin
        return false unless ffi_available?
        TreeHaver::Backends::FFI::Native.try_load!
        true
      rescue TreeHaver::NotAvailable, LoadError
        false
      end
    end

    # Check if a TOML grammar library is available
    # Check if a TOML grammar library is available via environment variable
    def toml_grammar_available?
      return @toml_grammar_available if defined?(@toml_grammar_available)
      path = find_toml_grammar_path
      @toml_grammar_available = path && File.exist?(path)
    end

    # Find the path to a TOML grammar library from environment variable
    #
    # Grammar paths should be configured via TREE_SITTER_TOML_PATH environment variable.
    # This keeps configuration explicit and avoids magic path guessing.
    #
    # @return [String, nil] path from environment variable, or nil if not set
    def find_toml_grammar_path
      ENV["TREE_SITTER_TOML_PATH"]
    end

    # Get a summary of available dependencies (for debugging)
    def summary
      {
        ffi: ffi_available?,
        mri_backend: mri_backend_available?,
        rust_backend: rust_backend_available?,
        java_backend: java_backend_available?,
        jruby: jruby?,
        libtree_sitter: libtree_sitter_available?,
        toml_grammar: toml_grammar_available?,
      }
    end
  end
end

RSpec.configure do |config|
  # Define exclusion filters for optional dependencies
  # Tests tagged with these will be skipped when the dependency is not available

  config.before(:suite) do
    # Print dependency summary if TREE_HAVER_DEBUG is set
    if ENV["TREE_HAVER_DEBUG"]
      puts "\n=== TreeHaver Test Dependencies ==="
      TreeHaverDependencies.summary.each do |dep, available|
        status = available ? "✓ available" : "✗ not available"
        puts "  #{dep}: #{status}"
      end
      puts "===================================\n"
    end
  end

  # ============================================================
  # Positive tags: run when dependency IS available
  # ============================================================

  # FFI availability is checked dynamically per-test (not at load time)
  # because FFI becomes unavailable after MRI backend is used.
  # When running via `rake spec`, FFI tests run first in a clean environment.
  config.before(:each, :ffi) do
    skip "FFI backend not available (MRI backend may have been used)" unless TreeHaverDependencies.ffi_available?
  end

  # Skip tests tagged :mri_backend when ruby_tree_sitter is not available
  config.filter_run_excluding mri_backend: true unless TreeHaverDependencies.mri_backend_available?

  # Skip tests tagged :rust_backend when tree_stump is not available
  config.filter_run_excluding rust_backend: true unless TreeHaverDependencies.rust_backend_available?

  # Skip tests tagged :java_backend when Java backend is not available
  config.filter_run_excluding java_backend: true unless TreeHaverDependencies.java_backend_available?

  # Skip tests tagged :jruby when not running on JRuby
  config.filter_run_excluding jruby: true unless TreeHaverDependencies.jruby?

  # Skip tests tagged :libtree_sitter when libtree-sitter.so is not loadable
  config.filter_run_excluding libtree_sitter: true unless TreeHaverDependencies.libtree_sitter_available?

  # Skip tests tagged :toml_grammar when no TOML grammar is available
  config.filter_run_excluding toml_grammar: true unless TreeHaverDependencies.toml_grammar_available?

  # Convenience: :native_parsing requires both libtree_sitter and toml_grammar
  config.filter_run_excluding native_parsing: true unless TreeHaverDependencies.libtree_sitter_available? &&
    TreeHaverDependencies.toml_grammar_available?

  # ============================================================
  # Negated tags: run when dependency is NOT available
  # Use these to test fallback/error behavior when deps are missing
  # ============================================================

  # NOTE: :not_ffi tag is not provided because FFI availability is dynamic.
  # FFI becomes unavailable after MRI backend is used (due to libtree-sitter
  # runtime conflicts that cause segfaults). Since test order determines FFI
  # availability, a static :not_ffi filter would be unreliable. Tests that
  # need to verify behavior when FFI is unavailable should mock
  # TreeHaver::Backends::FFI.available? instead.

  # Skip tests tagged :not_mri_backend when ruby_tree_sitter IS available
  config.filter_run_excluding not_mri_backend: true if TreeHaverDependencies.mri_backend_available?

  # Skip tests tagged :not_rust_backend when tree_stump IS available
  config.filter_run_excluding not_rust_backend: true if TreeHaverDependencies.rust_backend_available?

  # Skip tests tagged :not_java_backend when Java backend IS available
  config.filter_run_excluding not_java_backend: true if TreeHaverDependencies.java_backend_available?

  # Skip tests tagged :not_jruby when running on JRuby
  config.filter_run_excluding not_jruby: true if TreeHaverDependencies.jruby?

  # Skip tests tagged :not_libtree_sitter when libtree-sitter.so IS loadable
  config.filter_run_excluding not_libtree_sitter: true if TreeHaverDependencies.libtree_sitter_available?

  # Skip tests tagged :not_toml_grammar when a TOML grammar IS available
  config.filter_run_excluding not_toml_grammar: true if TreeHaverDependencies.toml_grammar_available?
end
