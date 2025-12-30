# frozen_string_literal: true

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
# [:mri_backend]
#   ruby_tree_sitter gem is available.
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
            require "ruby_tree_sitter"
            # Record that MRI backend is now loaded - this is critical for
            # conflict detection with FFI backend
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
        # @return [String, nil] path from environment variable, or nil if not set
        def find_toml_grammar_path
          ENV["TREE_SITTER_TOML_PATH"]
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

      puts "\n=== TreeHaver Test Dependencies ==="
      deps.summary.each do |dep, available|
        status = case available
        when true then "✓ available"
        when false then "✗ not available"
        else available.to_s
        end
        puts "  #{dep}: #{status}"
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

  # FFI availability is checked dynamically per-test (not at load time)
  # because FFI becomes unavailable after MRI backend is used.
  config.before(:each, :ffi_backend) do
    skip "FFI backend not available (MRI backend may have been used)" unless deps.ffi_available?
  end

  config.filter_run_excluding(mri_backend: true) unless deps.mri_backend_available?
  config.filter_run_excluding(rust_backend: true) unless deps.rust_backend_available?
  config.filter_run_excluding(java_backend: true) unless deps.java_backend_available?
  config.filter_run_excluding(prism_backend: true) unless deps.prism_available?
  config.filter_run_excluding(psych_backend: true) unless deps.psych_available?
  config.filter_run_excluding(commonmarker_backend: true) unless deps.commonmarker_available?
  config.filter_run_excluding(markly_backend: true) unless deps.markly_available?
  config.filter_run_excluding(citrus_backend: true) unless deps.citrus_available?

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

  config.filter_run_excluding(libtree_sitter: true) unless deps.libtree_sitter_available?
  config.filter_run_excluding(bash_grammar: true) unless deps.tree_sitter_bash_available?
  config.filter_run_excluding(toml_grammar: true) unless deps.tree_sitter_toml_available?
  config.filter_run_excluding(json_grammar: true) unless deps.tree_sitter_json_available?
  config.filter_run_excluding(jsonc_grammar: true) unless deps.tree_sitter_jsonc_available?

  # ============================================================
  # Language Parsing Capability Tags
  # ============================================================
  # Tags: *_parsing - require ANY parser for a language (any backend that can parse it)
  #   :toml_parsing   - any TOML parser (tree-sitter-toml OR toml-rb/Citrus)
  #   :markdown_parsing - any Markdown parser (commonmarker OR markly)
  #   :native_parsing - any native tree-sitter backend + grammar

  config.filter_run_excluding(toml_parsing: true) unless deps.any_toml_backend_available?
  config.filter_run_excluding(markdown_parsing: true) unless deps.any_markdown_backend_available?
  config.filter_run_excluding(native_parsing: true) unless deps.libtree_sitter_available? && deps.toml_grammar_available?

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

  # TreeHaver backends
  config.filter_run_excluding(not_mri_backend: true) if deps.mri_backend_available?
  config.filter_run_excluding(not_rust_backend: true) if deps.rust_backend_available?
  config.filter_run_excluding(not_java_backend: true) if deps.java_backend_available?
  config.filter_run_excluding(not_prism_backend: true) if deps.prism_available?
  config.filter_run_excluding(not_psych_backend: true) if deps.psych_available?
  config.filter_run_excluding(not_commonmarker_backend: true) if deps.commonmarker_available?
  config.filter_run_excluding(not_markly_backend: true) if deps.markly_available?
  config.filter_run_excluding(not_citrus_backend: true) if deps.citrus_available?

  # Ruby engines
  config.filter_run_excluding(not_mri_engine: true) if deps.mri?
  config.filter_run_excluding(not_jruby_engine: true) if deps.jruby?
  config.filter_run_excluding(not_truffleruby_engine: true) if deps.truffleruby?

  # Tree-sitter grammars
  config.filter_run_excluding(not_libtree_sitter: true) if deps.libtree_sitter_available?
  config.filter_run_excluding(not_bash_grammar: true) if deps.tree_sitter_bash_available?
  config.filter_run_excluding(not_toml_grammar: true) if deps.tree_sitter_toml_available?
  config.filter_run_excluding(not_json_grammar: true) if deps.tree_sitter_json_available?
  config.filter_run_excluding(not_jsonc_grammar: true) if deps.tree_sitter_jsonc_available?

  # Language parsing capabilities
  config.filter_run_excluding(not_toml_parsing: true) if deps.any_toml_backend_available?
  config.filter_run_excluding(not_markdown_parsing: true) if deps.any_markdown_backend_available?

  # Specific libraries
  config.filter_run_excluding(not_toml_rb: true) if deps.toml_rb_available?
end
