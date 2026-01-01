# frozen_string_literal: true

require "set"

# TreeHaver RSpec Dependency Tags
#
# This module provides dependency detection helpers for conditional test execution
# across all gems in the TreeHaver/ast-merge family. It detects which optional
# dependencies are available and configures RSpec to skip tests that require
# unavailable dependencies.
#
# @example Loading in spec_helper.rb
#   require "tree_haver/rspec/dependency_tags"
#
# @example Usage in specs
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
# @example Negated tags (for testing behavior when dependencies are NOT available)
#   it "only runs when ruby_tree_sitter is NOT available", :not_mri_backend do
#     # This test only runs when ruby_tree_sitter gem is NOT available
#   end
#
# @example Backend-specific tags
#   it "requires Prism backend", :prism_backend do
#     # This test only runs when Prism is available
#   end
#
#   it "requires Psych backend", :psych_backend do
#     # This test only runs when Psych is available
#   end
#
#   it "requires Commonmarker backend", :commonmarker_backend do
#     # This test only runs when commonmarker gem is available
#   end
#
#   it "requires Markly backend", :markly_backend do
#     # This test only runs when markly gem is available
#   end
#
#   it "requires Citrus backend", :citrus_backend do
#     # This test only runs when Citrus gem is available
#   end
#
# @example Language-specific grammar tags (for *-merge gems)
#   it "requires tree-sitter-bash", :bash_grammar do
#     # This test only runs when bash grammar is available and parsing works
#   end
#
#   it "requires tree-sitter-json", :json_grammar do
#     # This test only runs when json grammar is available and parsing works
#   end
#
# == Available Tags
#
# === Naming Conventions
#
# - `*_backend` = TreeHaver backends (mri, rust, ffi, java, prism, psych, commonmarker, markly, citrus)
# - `*_engine` = Ruby engines (mri, jruby, truffleruby)
# - `*_grammar` = tree-sitter grammar files (.so)
# - `*_parsing` = any parsing capability for a language (combines multiple backends/grammars)
# - `*_merge` = ast-merge family gems (toml-merge, json-merge, etc.)
#
# === Positive Tags (run when dependency IS available)
#
# ==== TreeHaver Backend Tags (*_backend)
#
# [:ffi_backend]
#   FFI backend is available. Checked dynamically per-test because FFI becomes
#   unavailable after MRI backend is used (due to libtree-sitter runtime conflicts).
#   Legacy alias: :ffi
#
# [:ffi_backend_only]
#   ISOLATED FFI tag - use when running FFI tests in isolation (e.g., ffi_specs task).
#   Does NOT trigger mri_backend_available? check, preventing MRI from being loaded.
#   Use this tag for tests that must run before MRI backend is loaded.
#
# [:mri_backend]
#   ruby_tree_sitter gem is available.
#
# [:mri_backend_only]
#   ISOLATED MRI tag - use when running MRI tests and FFI must not be checked.
#   Does NOT trigger ffi_available? check, preventing FFI availability detection.
#   Use this tag for tests that should run without FFI interference.
#
# [:rust_backend]
#   tree_stump gem is available.
#
# [:java_backend]
#   Java backend is available (requires JRuby + java-tree-sitter/jtreesitter).
#
# [:prism_backend]
#   Prism gem is available.
#
# [:psych_backend]
#   Psych is available (stdlib, should always be true).
#
# [:commonmarker_backend]
#   commonmarker gem is available.
#
# [:markly_backend]
#   markly gem is available.
#
# [:citrus_backend]
#   Citrus gem is available.
#
# ==== Ruby Engine Tags (*_engine)
#
# [:mri_engine]
#   Running on MRI (CRuby).
#
# [:jruby_engine]
#   Running on JRuby.
#
# [:truffleruby_engine]
#   Running on TruffleRuby.
#
# ==== Tree-Sitter Grammar Tags (*_grammar)
#
# [:libtree_sitter]
#   libtree-sitter.so is loadable via FFI.
#
# [:bash_grammar]
#   tree-sitter-bash grammar is available and parsing works.
#
# [:toml_grammar]
#   tree-sitter-toml grammar is available and parsing works.
#
# [:json_grammar]
#   tree-sitter-json grammar is available and parsing works.
#
# [:jsonc_grammar]
#   tree-sitter-jsonc grammar is available and parsing works.
#
# ==== Language Parsing Capability Tags (*_parsing)
#
# [:toml_parsing]
#   At least one TOML parser (tree-sitter-toml OR toml-rb/Citrus) is available.
#
# [:markdown_parsing]
#   At least one markdown parser (commonmarker OR markly) is available.
#
# [:native_parsing]
#   A native tree-sitter backend and grammar are available.
#
# ==== Specific Library Tags
#
# [:toml_rb]
#   toml-rb gem is available (Citrus backend for TOML).
#
# === Negated Tags (run when dependency is NOT available)
#
# All positive tags have negated versions prefixed with `not_`:
# - :not_mri_backend, :not_rust_backend, :not_java_backend, etc.
# - :not_mri_engine, :not_jruby_engine, :not_truffleruby_engine
# - :not_libtree_sitter, :not_bash_grammar, :not_toml_grammar, etc.
# - :not_toml_parsing, :not_markdown_parsing
#
# == Backend Conflict Protection
#
# The MRI backend (ruby_tree_sitter) and FFI backend cannot coexist in the same
# process. Once MRI loads its native extension, FFI will segfault when trying
# to set a language on a parser.
#
# This module records backend usage when checking availability. When
# `mri_backend_available?` successfully loads ruby_tree_sitter, it calls
# `TreeHaver.record_backend_usage(:mri)`. This allows TreeHaver's conflict
# detection (`TreeHaver.conflicting_backends_for`) to properly identify when
# FFI would conflict with already-loaded backends.
#
# @see TreeHaver.record_backend_usage
# @see TreeHaver.conflicting_backends_for
# @see TreeHaver::Backends::BLOCKED_BY

require "tree_haver"

module TreeHaver
  module RSpec
    # Dependency detection helpers for conditional test execution
    module DependencyTags
      class << self
        # ============================================================
        # TreeHaver Backend Availability
        # ============================================================

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
        #
        # @return [Boolean] true if FFI backend is usable
        def ffi_available?
          # TruffleRuby's FFI doesn't support STRUCT_BY_VALUE return types
          # (used by ts_tree_root_node, ts_node_child, ts_node_start_point, etc.)
          return false if truffleruby?

          # Try to actually use the FFI backend
          path = find_toml_grammar_path
          return false unless path && File.exist?(path)

          TreeHaver.with_backend(:ffi) do
            TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
          end
          true
        rescue TreeHaver::BackendConflict, TreeHaver::NotAvailable, LoadError
          false
        rescue StandardError
          # Catch any other FFI-related errors (e.g., Polyglot::ForeignException)
          false
        end

        # Check if ruby_tree_sitter gem is available (MRI backend)
        #
        # The MRI backend only works on MRI Ruby (C extension).
        # When this returns true, it also records MRI backend usage with
        # TreeHaver.record_backend_usage(:mri). This is critical for conflict
        # detection - without it, FFI would not know that MRI has been loaded.
        #
        # @return [Boolean] true if ruby_tree_sitter gem is available
        def mri_backend_available?
          return @mri_backend_available if defined?(@mri_backend_available)

          # ruby_tree_sitter is a C extension that only works on MRI
          return @mri_backend_available = false unless mri?

          @mri_backend_available = begin
            # Note: gem is ruby_tree_sitter but requires tree_sitter
            require "tree_sitter"
            # Record that MRI backend is now loaded - this is critical for
            # conflict detection with FFI backend
            TreeHaver.record_backend_usage(:mri)
            true
          rescue LoadError
            false
          end
        end

        # Check if FFI backend is available WITHOUT loading MRI first
        #
        # This is used for the :ffi_backend_only tag which runs FFI tests
        # in isolation before MRI can be loaded. Unlike ffi_available?,
        # this method does NOT check mri_backend_available?.
        #
        # @return [Boolean] true if FFI backend is usable in isolation
        def ffi_backend_only_available?
          # TruffleRuby's FFI doesn't support STRUCT_BY_VALUE return types
          return false if truffleruby?

          # Check if FFI gem is available without loading tree_sitter
          begin
            require "ffi"
          rescue LoadError
            return false
          end

          # Try to actually use the FFI backend
          path = find_toml_grammar_path
          return false unless path && File.exist?(path)

          TreeHaver.with_backend(:ffi) do
            TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
          end
          true
        rescue TreeHaver::BackendConflict, TreeHaver::NotAvailable, LoadError
          false
        rescue StandardError
          # Catch any other FFI-related errors
          false
        end

        # Check if MRI backend is available WITHOUT checking FFI availability
        #
        # This is used for the :mri_backend_only tag which runs MRI tests
        # without triggering any FFI availability checks.
        #
        # @return [Boolean] true if MRI backend is usable
        def mri_backend_only_available?
          return @mri_backend_only_available if defined?(@mri_backend_only_available)

          # ruby_tree_sitter is a C extension that only works on MRI
          return @mri_backend_only_available = false unless mri?

          @mri_backend_only_available = begin
            require "tree_sitter"
            TreeHaver.record_backend_usage(:mri)
            true
          rescue LoadError
            false
          end
        end

        # Check if tree_stump gem is available (Rust backend)
        #
        # The Rust backend only works on MRI Ruby (magnus uses MRI's C API).
        #
        # @return [Boolean] true if tree_stump gem is available
        def rust_backend_available?
          return @rust_backend_available if defined?(@rust_backend_available)

          # tree_stump uses magnus which requires MRI's C API
          return @rust_backend_available = false unless mri?

          @rust_backend_available = begin
            require "tree_stump"
            true
          rescue LoadError
            false
          end
        end

        # Check if Java backend is available (requires JRuby + java-tree-sitter / jtreesitter)
        #
        # @return [Boolean] true if Java backend is available
        def java_backend_available?
          return @java_backend_available if defined?(@java_backend_available)
          @java_backend_available = jruby? && TreeHaver::Backends::Java.available?
        end

        # Check if libtree-sitter runtime library is loadable
        #
        # @return [Boolean] true if libtree-sitter.so is loadable via FFI
        def libtree_sitter_available?
          return @libtree_sitter_available if defined?(@libtree_sitter_available)
          @libtree_sitter_available = begin
            return false unless ffi_available?
            TreeHaver::Backends::FFI::Native.try_load!
            true
          rescue TreeHaver::NotAvailable, LoadError
            false
          rescue StandardError
            # TruffleRuby raises Polyglot::ForeignException when FFI
            # encounters unsupported types like STRUCT_BY_VALUE
            false
          end
        end

        # Check if a TOML grammar library is available via environment variable
        #
        # @return [Boolean] true if TREE_SITTER_TOML_PATH points to an existing file
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
        # @return [String, nil] path to TOML grammar library, or nil if not found
        def find_toml_grammar_path
          # First check environment variable
          env_path = ENV["TREE_SITTER_TOML_PATH"]
          return env_path if env_path && File.exist?(env_path)

          # Use GrammarFinder to search standard paths
          finder = TreeHaver::GrammarFinder.new(:toml, validate: false)
          finder.find_library_path
        rescue StandardError
          # GrammarFinder might not be available or might fail
          nil
        end

        # Check if commonmarker gem is available
        #
        # @return [Boolean] true if commonmarker gem is available
        def commonmarker_available?
          return @commonmarker_available if defined?(@commonmarker_available)
          @commonmarker_available = TreeHaver::Backends::Commonmarker.available?
        end

        # Check if markly gem is available
        #
        # @return [Boolean] true if markly gem is available
        def markly_available?
          return @markly_available if defined?(@markly_available)
          @markly_available = TreeHaver::Backends::Markly.available?
        end

        # Check if prism gem is available
        #
        # @return [Boolean] true if Prism is available
        def prism_available?
          return @prism_available if defined?(@prism_available)
          @prism_available = TreeHaver::Backends::Prism.available?
        end

        # Check if psych is available (stdlib, should always be true)
        #
        # @return [Boolean] true if Psych is available
        def psych_available?
          return @psych_available if defined?(@psych_available)
          @psych_available = TreeHaver::Backends::Psych.available?
        end

        # Check if Citrus backend is available
        #
        # This checks if the citrus gem is installed and the backend works.
        #
        # @return [Boolean] true if Citrus backend is available
        def citrus_available?
          return @citrus_available if defined?(@citrus_available)
          @citrus_available = TreeHaver::Backends::Citrus.available?
        end

        # ============================================================
        # Ruby Engine Detection
        # ============================================================

        # Check if running on JRuby
        #
        # @return [Boolean] true if running on JRuby
        def jruby?
          defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
        end

        # Check if running on TruffleRuby
        #
        # @return [Boolean] true if running on TruffleRuby
        def truffleruby?
          defined?(RUBY_ENGINE) && RUBY_ENGINE == "truffleruby"
        end

        # Check if running on MRI (CRuby)
        #
        # @return [Boolean] true if running on MRI
        def mri?
          defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby"
        end

        # ============================================================
        # Language-Specific Grammar Availability
        # These check that parsing actually works, not just that a grammar exists
        # ============================================================

        # Check if tree-sitter-bash grammar is available and working
        #
        # @return [Boolean] true if bash grammar works
        def tree_sitter_bash_available?
          return @tree_sitter_bash_available if defined?(@tree_sitter_bash_available)
          @tree_sitter_bash_available = grammar_works?(:bash, "echo hello")
        end

        # Check if tree-sitter-toml grammar is available and working via TreeHaver
        #
        # @return [Boolean] true if toml grammar works
        def tree_sitter_toml_available?
          return @tree_sitter_toml_available if defined?(@tree_sitter_toml_available)
          @tree_sitter_toml_available = grammar_works?(:toml, 'key = "value"')
        end

        # Check if tree-sitter-json grammar is available and working
        #
        # @return [Boolean] true if json grammar works
        def tree_sitter_json_available?
          return @tree_sitter_json_available if defined?(@tree_sitter_json_available)
          @tree_sitter_json_available = grammar_works?(:json, '{"key": "value"}')
        end

        # Check if tree-sitter-jsonc grammar is available and working
        #
        # @return [Boolean] true if jsonc grammar works
        def tree_sitter_jsonc_available?
          return @tree_sitter_jsonc_available if defined?(@tree_sitter_jsonc_available)
          @tree_sitter_jsonc_available = grammar_works?(:jsonc, '{"key": "value" /* comment */}')
        end

        # Check if toml-rb gem is available and functional (Citrus backend for TOML)
        #
        # @return [Boolean] true if toml-rb gem is available and can parse TOML
        def toml_rb_available?
          return @toml_rb_available if defined?(@toml_rb_available)
          @toml_rb_available = begin
            require "toml-rb"
            # Verify it can actually parse - just requiring isn't enough
            TomlRB.parse('key = "value"')
            true
          rescue LoadError
            false
          rescue StandardError
            false
          end
        end

        # Check if at least one TOML backend is available
        #
        # @return [Boolean] true if any TOML backend works
        def any_toml_backend_available?
          tree_sitter_toml_available? || toml_rb_available?
        end

        # Check if at least one markdown backend is available
        #
        # @return [Boolean] true if any markdown backend works
        def any_markdown_backend_available?
          markly_available? || commonmarker_available?
        end

        def any_native_grammar_available?
          libtree_sitter_available? && (
            tree_sitter_bash_available? ||
              tree_sitter_toml_available? ||
              tree_sitter_json_available? ||
              tree_sitter_jsonc_available?
          )
        end

        # ============================================================
        # Summary and Reset
        # ============================================================

        # Get a summary of available dependencies (for debugging)
        #
        # @return [Hash{Symbol => Boolean}] map of dependency name to availability
        def summary
          {
            # TreeHaver backends (*_backend)
            ffi_backend: ffi_available?,
            mri_backend: mri_backend_available?,
            rust_backend: rust_backend_available?,
            java_backend: java_backend_available?,
            prism_backend: prism_available?,
            psych_backend: psych_available?,
            commonmarker_backend: commonmarker_available?,
            markly_backend: markly_available?,
            citrus_backend: citrus_available?,
            # Ruby engines (*_engine)
            ruby_engine: RUBY_ENGINE,
            mri_engine: mri?,
            jruby_engine: jruby?,
            truffleruby_engine: truffleruby?,
            # Tree-sitter grammars (*_grammar)
            libtree_sitter: libtree_sitter_available?,
            bash_grammar: tree_sitter_bash_available?,
            toml_grammar: tree_sitter_toml_available?,
            json_grammar: tree_sitter_json_available?,
            jsonc_grammar: tree_sitter_jsonc_available?,
            any_native_grammar: any_native_grammar_available?,
            # Language parsing capabilities (*_parsing)
            toml_parsing: any_toml_backend_available?,
            markdown_parsing: any_markdown_backend_available?,
            # Specific libraries
            toml_rb: toml_rb_available?,
          }
        end

        # Get environment variable summary for debugging
        #
        # @return [Hash{String => String}] relevant environment variables
        def env_summary
          {
            "TREE_SITTER_BASH_PATH" => ENV["TREE_SITTER_BASH_PATH"],
            "TREE_SITTER_TOML_PATH" => ENV["TREE_SITTER_TOML_PATH"],
            "TREE_SITTER_JSON_PATH" => ENV["TREE_SITTER_JSON_PATH"],
            "TREE_SITTER_JSONC_PATH" => ENV["TREE_SITTER_JSONC_PATH"],
            "TREE_SITTER_RUNTIME_LIB" => ENV["TREE_SITTER_RUNTIME_LIB"],
            "TREE_HAVER_BACKEND" => ENV["TREE_HAVER_BACKEND"],
            "TREE_HAVER_DEBUG" => ENV["TREE_HAVER_DEBUG"],
          }
        end

        # Reset all memoized availability checks
        #
        # Useful in tests that need to re-check availability after mocking.
        # Note: This does NOT undo backend usage recording.
        #
        # @return [void]
        def reset!
          instance_variables.each do |ivar|
            remove_instance_variable(ivar) if ivar.to_s.end_with?("_available")
          end
        end

        private

        # Generic helper to check if a grammar works by parsing test source
        #
        # @param language [Symbol] the language to test
        # @param test_source [String] sample source code to parse
        # @return [Boolean] true if parsing works without errors
        def grammar_works?(language, test_source)
          debug = ENV["TREE_HAVER_DEBUG"]
          env_var = "TREE_SITTER_#{language.to_s.upcase}_PATH"
          env_value = ENV[env_var]

          if debug
            puts "  [grammar_works? #{language}] ENV[#{env_var}] = #{env_value.inspect}"
            puts "  [grammar_works? #{language}] Attempting TreeHaver.parser_for(#{language.inspect})..."
          end

          parser = TreeHaver.parser_for(language)
          if debug
            puts "  [grammar_works? #{language}] Parser created: #{parser.class}"
            puts "  [grammar_works? #{language}] Parser backend: #{parser.respond_to?(:backend) ? parser.backend : "unknown"}"
          end

          result = parser.parse(test_source)
          success = !result.nil? && result.root_node && !result.root_node.has_error?

          if debug
            puts "  [grammar_works? #{language}] Parse result nil?: #{result.nil?}"
            puts "  [grammar_works? #{language}] Root node: #{result&.root_node&.class}"
            puts "  [grammar_works? #{language}] Has error?: #{result&.root_node&.has_error?}"
            puts "  [grammar_works? #{language}] Success: #{success}"
          end

          success
        rescue TreeHaver::NotAvailable, TreeHaver::Error, StandardError => e
          if debug
            puts "  [grammar_works? #{language}] Exception: #{e.class}: #{e.message}"
            puts "  [grammar_works? #{language}] Returning false"
          end
          false
        end
      end
    end
  end
end

# Configure RSpec with dependency-based exclusion filters
RSpec.configure do |config|
  deps = TreeHaver::RSpec::DependencyTags

  # Define exclusion filters for optional dependencies
  # Tests tagged with these will be skipped when the dependency is not available

  config.before(:suite) do
    # Print dependency summary if TREE_HAVER_DEBUG is set
    if ENV["TREE_HAVER_DEBUG"]
      puts "\n=== TreeHaver Environment Variables ==="
      deps.env_summary.each do |var, value|
        puts "  #{var}: #{value.inspect}"
      end

      # Only print full dependency summary if we're not running with blocked backends
      # The summary calls grammar availability checks which would load blocked backends
      current_blocked = TreeHaver::RSpec::DependencyTags.instance_variable_get(:@blocked_backends) || Set.new
      if current_blocked.any?
        puts "\n=== TreeHaver Test Dependencies (limited - running isolated tests) ==="
        puts "  blocked_backends: #{current_blocked.to_a.inspect}"
        puts "  (Skipping full summary to avoid loading blocked backends)"
      else
        puts "\n=== TreeHaver Test Dependencies ==="
        deps.summary.each do |dep, available|
          status = case available
          when true then "✓ available"
          when false then "✗ not available"
          else available.to_s
          end
          puts "  #{dep}: #{status}"
        end
      end
      puts "===================================\n"
    end
  end

  # ============================================================
  # TreeHaver Backend Tags
  # ============================================================
  # Tags: *_backend - require a specific TreeHaver backend to be available
  #
  # Native backends (load .so files):
  #   :ffi_backend, :mri_backend, :rust_backend, :java_backend
  # Pure-Ruby backends:
  #   :prism_backend, :psych_backend, :commonmarker_backend, :markly_backend, :citrus_backend
  #
  # Isolated backend tags (for running tests without loading conflicting backends):
  #   :ffi_backend_only - runs FFI tests without loading MRI backend
  #   :mri_backend_only - runs MRI tests without checking FFI availability

  # FFI availability is checked dynamically per-test (not at load time)
  # because FFI becomes unavailable after MRI backend is used.
  # When running with :ffi_backend_only tag, this hook defers to the isolated check.
  config.before(:each, :ffi_backend) do |example|
    # If also tagged with :ffi_backend_only, let that hook handle the check
    next if example.metadata[:ffi_backend_only]

    skip "FFI backend not available (MRI backend may have been used)" unless deps.ffi_available?
  end

  # ISOLATED FFI TAG: Checked dynamically but does NOT trigger mri_backend_available?
  # Use this tag for tests that must run before MRI is loaded (e.g., in ffi_specs task)
  config.before(:each, :ffi_backend_only) do
    skip "FFI backend not available (isolated check)" unless deps.ffi_backend_only_available?
  end

  # ISOLATED MRI TAG: Checked dynamically but does NOT trigger ffi_available?
  # Use this tag for tests that should run without FFI interference
  config.before(:each, :mri_backend_only) do
    skip "MRI backend not available (isolated check)" unless deps.mri_backend_only_available?
  end

  # ============================================================
  # Dynamic Backend Exclusions (using BLOCKED_BY)
  # ============================================================
  # When running with *_backend_only tags, we skip availability checks for
  # backends that would block the isolated backend. This prevents loading
  # conflicting backends before isolated tests run.
  #
  # For example, when running with --tag ffi_backend_only:
  # - FFI is blocked by [:mri] (from BLOCKED_BY)
  # - So we skip mri_backend_available? to prevent loading MRI
  #
  # This is dynamic based on TreeHaver::Backends::BLOCKED_BY configuration.

  # Map of backend symbols to their availability check methods
  backend_availability_methods = {
    mri: :mri_backend_available?,
    rust: :rust_backend_available?,
    ffi: :ffi_available?,
    java: :java_backend_available?,
    prism: :prism_available?,
    psych: :psych_available?,
    commonmarker: :commonmarker_available?,
    markly: :markly_available?,
    citrus: :citrus_available?,
  }

  # Map of backend symbols to their RSpec tag names
  backend_tags = {
    mri: :mri_backend,
    rust: :rust_backend,
    ffi: :ffi_backend,
    java: :java_backend,
    prism: :prism_backend,
    psych: :psych_backend,
    commonmarker: :commonmarker_backend,
    markly: :markly_backend,
    citrus: :citrus_backend,
  }

  # Determine which backends should NOT have availability checked
  # based on which *_backend_only tag is being run
  blocked_backends = Set.new

  # Check which *_backend_only tags are being run and block their conflicting backends
  # config.inclusion_filter contains tags passed via --tag on command line
  inclusion_rules = config.inclusion_filter.rules

  # If filter.rules is empty, check ARGV directly for --tag options
  # This handles the case where RSpec hasn't processed filters yet during configuration
  if inclusion_rules.empty?
    ARGV.each_with_index do |arg, i|
      if arg == "--tag" && ARGV[i + 1]
        tag_value = ARGV[i + 1].to_sym
        inclusion_rules[tag_value] = true
      elsif arg.start_with?("--tag=")
        tag_value = arg.sub("--tag=", "").to_sym
        inclusion_rules[tag_value] = true
      end
    end
  end

  TreeHaver::Backends::BLOCKED_BY.each do |backend, blockers|
    # Check if we're running this backend's isolated tests
    isolated_tag = :"#{backend}_backend_only"
    if inclusion_rules[isolated_tag]
      # Add all backends that would block this one
      blockers.each { |blocker| blocked_backends << blocker }
    end
  end

  # Store blocked_backends in a module variable so before(:suite) can access it
  TreeHaver::RSpec::DependencyTags.instance_variable_set(:@blocked_backends, blocked_backends)

  # Now configure exclusions, skipping availability checks for blocked backends
  backend_tags.each do |backend, tag|
    next if blocked_backends.include?(backend)

    # FFI is handled specially with before(:each) hook above
    next if backend == :ffi

    availability_method = backend_availability_methods[backend]
    config.filter_run_excluding(tag => true) unless deps.public_send(availability_method)
  end

  # ============================================================
  # Ruby Engine Tags
  # ============================================================
  # Tags: *_engine - require a specific Ruby engine
  #   :mri_engine, :jruby_engine, :truffleruby_engine

  config.filter_run_excluding(mri_engine: true) unless deps.mri?
  config.filter_run_excluding(jruby_engine: true) unless deps.jruby?
  config.filter_run_excluding(truffleruby_engine: true) unless deps.truffleruby?

  # ============================================================
  # Tree-Sitter Grammar Tags
  # ============================================================
  # Tags: *_grammar - require a specific tree-sitter grammar (.so file)
  #   :bash_grammar, :toml_grammar, :json_grammar, :jsonc_grammar
  #
  # Also: :libtree_sitter - requires the libtree-sitter runtime library
  #
  # NOTE: When running with *_backend_only tags, we skip these checks to avoid
  # loading blocked backends. The grammar checks use TreeHaver.parser_for which
  # would load the default backend (MRI) and block FFI.

  # Skip grammar availability checks if any backend is blocked
  # (i.e., we're running isolated backend tests)
  if blocked_backends.none?
    config.filter_run_excluding(libtree_sitter: true) unless deps.libtree_sitter_available?
    config.filter_run_excluding(bash_grammar: true) unless deps.tree_sitter_bash_available?
    config.filter_run_excluding(toml_grammar: true) unless deps.tree_sitter_toml_available?
    config.filter_run_excluding(json_grammar: true) unless deps.tree_sitter_json_available?
    config.filter_run_excluding(jsonc_grammar: true) unless deps.tree_sitter_jsonc_available?
  end

  # ============================================================
  # Language Parsing Capability Tags
  # ============================================================
  # Tags: *_parsing - require ANY parser for a language (any backend that can parse it)
  #   :toml_parsing   - any TOML parser (tree-sitter-toml OR toml-rb/Citrus)
  #   :markdown_parsing - any Markdown parser (commonmarker OR markly)
  #   :native_parsing - any native tree-sitter backend + grammar
  #
  # NOTE: any_toml_backend_available? calls tree_sitter_toml_available? which
  # triggers grammar_works? and loads MRI. Skip when running isolated tests.

  if blocked_backends.none?
    config.filter_run_excluding(toml_parsing: true) unless deps.any_toml_backend_available?
    config.filter_run_excluding(markdown_parsing: true) unless deps.any_markdown_backend_available?
    config.filter_run_excluding(native_parsing: true) unless deps.any_native_grammar_available?
  end

  # ============================================================
  # Specific Library Tags
  # ============================================================
  # Tags for specific gems/libraries (not backends, but dependencies)
  #   :toml_rb - the toml-rb gem (Citrus-based TOML parser)

  config.filter_run_excluding(toml_rb: true) unless deps.toml_rb_available?

  # ============================================================
  # Negated Tags (run when dependency is NOT available)
  # ============================================================
  # Prefix: not_* - exclude tests when the dependency IS available

  # NOTE: :not_ffi_backend tag is not provided because FFI availability is dynamic.

  # TreeHaver backends - handled dynamically to respect blocked backends
  backend_tags.each do |backend, tag|
    next if blocked_backends.include?(backend)

    # FFI is handled specially (availability is always dynamic)
    next if backend == :ffi

    negated_tag = :"not_#{tag}"
    availability_method = backend_availability_methods[backend]
    config.filter_run_excluding(negated_tag => true) if deps.public_send(availability_method)
  end

  # Ruby engines
  config.filter_run_excluding(not_mri_engine: true) if deps.mri?
  config.filter_run_excluding(not_jruby_engine: true) if deps.jruby?
  config.filter_run_excluding(not_truffleruby_engine: true) if deps.truffleruby?

  # Tree-sitter grammars - skip when running isolated backend tests
  if blocked_backends.none?
    config.filter_run_excluding(not_libtree_sitter: true) if deps.libtree_sitter_available?
    config.filter_run_excluding(not_bash_grammar: true) if deps.tree_sitter_bash_available?
    config.filter_run_excluding(not_toml_grammar: true) if deps.tree_sitter_toml_available?
    config.filter_run_excluding(not_json_grammar: true) if deps.tree_sitter_json_available?
    config.filter_run_excluding(not_jsonc_grammar: true) if deps.tree_sitter_jsonc_available?

    # Language parsing capabilities
    config.filter_run_excluding(not_toml_parsing: true) if deps.any_toml_backend_available?
    config.filter_run_excluding(not_markdown_parsing: true) if deps.any_markdown_backend_available?
  end

  # Specific libraries
  config.filter_run_excluding(not_toml_rb: true) if deps.toml_rb_available?
end
