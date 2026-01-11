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
# [:rbs_backend]
#   RBS gem is available (official RBS parser, MRI only).
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
# [:rbs_grammar]
#   tree-sitter-rbs grammar is available and parsing works.
#
# ==== Language Parsing Capability Tags (*_parsing)
#
# [:toml_parsing]
#   At least one TOML parser (tree-sitter-toml OR toml-rb/Citrus) is available.
#
# [:markdown_parsing]
#   At least one markdown parser (commonmarker OR markly) is available.
#
# [:rbs_parsing]
#   At least one RBS parser (rbs gem OR tree-sitter-rbs) is available.
#
# [:native_parsing]
#   A native tree-sitter backend and grammar are available.
#
# ==== Specific Library Tags (*_gem)
#
# [:toml_rb_gem]
#   toml-rb gem is available (Citrus backend for TOML).
#
# [:rbs_gem]
#   rbs gem is available (official RBS parser, MRI only).
#   Note: Also available as :rbs_backend for consistency with other parser backends.
#
# === Negated Tags (run when dependency is NOT available)
#
# All positive tags have negated versions prefixed with `not_`:
# - :not_mri_backend, :not_rust_backend, :not_java_backend, :not_rbs_backend, etc.
# - :not_mri_engine, :not_jruby_engine, :not_truffleruby_engine
# - :not_libtree_sitter, :not_bash_grammar, :not_toml_grammar, :not_rbs_grammar, etc.
# - :not_toml_parsing, :not_markdown_parsing, :not_rbs_parsing
# - :not_toml_rb_gem, :not_rbs_gem
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
        # Backend Selection via Environment Variables
        # ============================================================
        #
        # Three environment variables control backend availability:
        #
        # TREE_HAVER_BACKEND - Single backend selection (the primary one to use)
        #   Values: auto, mri, ffi, rust, java, citrus, prism, psych, commonmarker, markly
        #   Default: auto
        #
        # TREE_HAVER_NATIVE_BACKEND - Allow list for native backends
        #   Values: all, none, or comma-separated list (mri, ffi, rust, java)
        #   Default: all (empty or unset)
        #   Example: TREE_HAVER_NATIVE_BACKEND=mri,ffi
        #
        # TREE_HAVER_RUBY_BACKEND - Allow list for pure Ruby backends
        #   Values: all, none, or comma-separated list (citrus, prism, psych, commonmarker, markly)
        #   Default: all (empty or unset)
        #   Example: TREE_HAVER_RUBY_BACKEND=citrus
        #
        # This ensures tests tagged with :mri_backend only run when MRI is allowed, etc.

        # Get the selected backend from TREE_HAVER_BACKEND
        #
        # @return [Symbol] the selected backend (:auto if not set)
        def selected_backend
          return @selected_backend if defined?(@selected_backend)
          @selected_backend = TreeHaver.backend
        end

        # Get allowed native backends from TREE_HAVER_NATIVE_BACKEND
        #
        # @return [Array<Symbol>] list of allowed native backends, or [:all] or [:none]
        def allowed_native_backends
          return @allowed_native_backends if defined?(@allowed_native_backends)
          @allowed_native_backends = TreeHaver.allowed_native_backends
        end

        # Get allowed Ruby backends from TREE_HAVER_RUBY_BACKEND
        #
        # @return [Array<Symbol>] list of allowed Ruby backends, or [:all] or [:none]
        def allowed_ruby_backends
          return @allowed_ruby_backends if defined?(@allowed_ruby_backends)
          @allowed_ruby_backends = TreeHaver.allowed_ruby_backends
        end

        # Check if a specific backend is allowed based on environment variables
        #
        # Delegates to TreeHaver.backend_allowed? which handles both
        # TREE_HAVER_NATIVE_BACKEND and TREE_HAVER_RUBY_BACKEND.
        #
        # @param backend [Symbol] the backend to check (:mri, :ffi, :citrus, etc.)
        # @return [Boolean] true if the backend is allowed
        def backend_allowed?(backend)
          TreeHaver.backend_allowed?(backend)
        end

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
          # If TREE_HAVER_BACKEND explicitly selects a different native backend,
          # FFI is not available for testing
          return false unless backend_allowed?(:ffi)

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

          # If TREE_HAVER_BACKEND explicitly selects a different native backend,
          # MRI is not available for testing
          return @mri_backend_available = false unless backend_allowed?(:mri)

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
        # This method is primarily for backwards compatibility with the legacy
        # :ffi_backend_only tag. The preferred approach is to use the standard
        # :ffi_backend tag, which now also triggers isolated_test_mode when
        # used with --tag ffi_backend.
        #
        # @return [Boolean] true if FFI backend is usable in isolation
        # @deprecated Use :ffi_backend tag instead of :ffi_backend_only
        def ffi_backend_only_available?
          # If TREE_HAVER_BACKEND explicitly selects a different native backend,
          # FFI is not available for testing
          return false unless backend_allowed?(:ffi)

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

          # If TREE_HAVER_BACKEND explicitly selects a different native backend,
          # MRI is not available for testing
          return @mri_backend_only_available = false unless backend_allowed?(:mri)

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

          # If TREE_HAVER_BACKEND explicitly selects a different native backend,
          # Rust is not available for testing
          return @rust_backend_available = false unless backend_allowed?(:rust)

          # tree_stump uses magnus which requires MRI's C API
          return @rust_backend_available = false unless mri?

          @rust_backend_available = begin
            require "tree_stump"
            true
          rescue LoadError
            false
          end
        end

        # Check if Java backend is available AND can actually load grammars
        #
        # The Java backend requires:
        # 1. Running on JRuby
        # 2. java-tree-sitter (jtreesitter) JAR available
        # 3. Grammars built for java-tree-sitter's Foreign Function Memory API
        #
        # Note: Standard `.so` files built for MRI's tree-sitter C bindings are NOT
        # compatible with java-tree-sitter. You need grammar JARs from Maven Central
        # or libraries specifically built for Java FFM API.
        #
        # @return [Boolean] true if Java backend is available and can load grammars
        def java_backend_available?
          return @java_backend_available if defined?(@java_backend_available)

          # If TREE_HAVER_BACKEND explicitly selects a different native backend,
          # Java is not available for testing
          return @java_backend_available = false unless backend_allowed?(:java)

          # Must be on JRuby and have java-tree-sitter classes available
          return @java_backend_available = false unless jruby?
          return @java_backend_available = false unless TreeHaver::Backends::Java.available?

          # Try to actually load a grammar to verify the backend works end-to-end
          # This catches the case where Java classes load but grammars fail
          # (e.g., when using MRI-built .so files on JRuby)
          @java_backend_available = java_grammar_loadable?
        end

        # Check if Java backend can actually load a grammar
        #
        # This does a live test by trying to load a TOML grammar via the Java backend.
        # It catches the common failure case where java-tree-sitter is available but
        # the grammar .so files are incompatible (built for MRI, not java-tree-sitter).
        #
        # @return [Boolean] true if a grammar can be loaded via Java backend
        # @api private
        def java_grammar_loadable?
          return false unless jruby?

          path = find_toml_grammar_path
          return false unless path && File.exist?(path)

          TreeHaver.with_backend(:java) do
            TreeHaver::Backends::Java::Language.from_library(path, symbol: "tree_sitter_toml")
          end
          true
        rescue TreeHaver::NotAvailable, TreeHaver::Error, LoadError
          false
        rescue StandardError
          # Catch any other Java-related errors
          false
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
        # Uses BackendRegistry which allows commonmarker-merge to register its checker.
        #
        # @return [Boolean] true if commonmarker gem is available
        def commonmarker_available?
          return @commonmarker_available if defined?(@commonmarker_available)
          @commonmarker_available = TreeHaver::BackendRegistry.available?(:commonmarker)
        end

        # Check if markly gem is available
        #
        # Uses BackendRegistry which allows markly-merge to register its checker.
        #
        # @return [Boolean] true if markly gem is available
        def markly_available?
          return @markly_available if defined?(@markly_available)
          @markly_available = TreeHaver::BackendRegistry.available?(:markly)
        end

        # Check if prism gem is available
        #
        # @return [Boolean] true if Prism is available
        def prism_available?
          return @prism_available if defined?(@prism_available)
          @prism_available = TreeHaver::BackendRegistry.available?(:prism)
        end

        # Check if psych is available (stdlib, should always be true)
        #
        # @return [Boolean] true if Psych is available
        def psych_available?
          return @psych_available if defined?(@psych_available)
          @psych_available = TreeHaver::BackendRegistry.available?(:psych)
        end

        # Check if Citrus backend is available
        #
        # This checks if the citrus gem is installed and the backend works.
        #
        # @return [Boolean] true if Citrus backend is available
        def citrus_available?
          return @citrus_available if defined?(@citrus_available)
          @citrus_available = TreeHaver::BackendRegistry.available?(:citrus)
        end

        # Check if Parslet backend is available
        #
        # This checks if the parslet gem is installed and the backend works.
        #
        # @return [Boolean] true if Parslet backend is available
        def parslet_available?
          return @parslet_available if defined?(@parslet_available)
          @parslet_available = TreeHaver::BackendRegistry.available?(:parslet)
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

        # Check if tree-sitter-rbs grammar is available and working
        #
        # @return [Boolean] true if rbs grammar works
        def tree_sitter_rbs_available?
          return @tree_sitter_rbs_available if defined?(@tree_sitter_rbs_available)
          @tree_sitter_rbs_available = grammar_works?(:rbs, "class Foo end")
        end

        # Check if the RBS gem is available and functional
        #
        # The RBS gem only works on MRI Ruby (C extension).
        #
        # @return [Boolean] true if rbs gem is available and can parse RBS
        def rbs_gem_available?
          return @rbs_gem_available if defined?(@rbs_gem_available)
          @rbs_gem_available = begin
            require "rbs"
            # Verify it can actually parse - just requiring isn't enough
            buffer = ::RBS::Buffer.new(name: "test.rbs", content: "class Foo end")
            ::RBS::Parser.parse_signature(buffer)
            true
          rescue LoadError
            false
          rescue StandardError
            false
          end
        end

        # Alias for rbs_gem_available? - for consistency with other backends
        # Use :rbs_backend tag in specs for consistency with :prism_backend, :psych_backend, etc.
        #
        # @return [Boolean] true if rbs gem is available
        alias_method :rbs_backend_available?, :rbs_gem_available?

        # Check if at least one RBS backend is available
        #
        # @return [Boolean] true if any RBS backend works
        def any_rbs_backend_available?
          rbs_gem_available? || tree_sitter_rbs_available?
        end

        # Check if toml-rb gem is available and functional (Citrus backend for TOML)
        #
        # @return [Boolean] true if toml-rb gem is available and can parse TOML
        def toml_rb_gem_available?
          return @toml_rb_gem_available if defined?(@toml_rb_gem_available)
          @toml_rb_gem_available = begin
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

        # Check if toml gem is available and functional (Parslet backend for TOML)
        #
        # @return [Boolean] true if toml gem is available and can parse TOML
        def toml_gem_available?
          return @toml_gem_available if defined?(@toml_gem_available)
          @toml_gem_available = begin
            require "toml"
            # Verify it can actually parse - just requiring isn't enough
            TOML.load('key = "value"')
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
          tree_sitter_toml_available? || toml_rb_gem_available? || toml_gem_available?
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

        # Determine which backends are blocked based on environment and ARGV
        #
        # This replicates the logic from RSpec.configure to determine blocked
        # backends BEFORE the RSpec.configure block has run. This is necessary
        # because summary may be called in a before(:suite) hook that runs
        # before the blocked_backends instance variable is set.
        #
        # @return [Set<Symbol>] set of blocked backend symbols
        def compute_blocked_backends
          blocked = Set.new

          # Check TREE_HAVER_BACKEND environment variable
          env_backend = ENV["TREE_HAVER_BACKEND"]
          if env_backend && !env_backend.empty? && env_backend != "auto"
            backend_sym = env_backend.to_sym
            TreeHaver::Backends::BLOCKED_BY[backend_sym]&.each { |blocker| blocked << blocker }
          end

          # Check ARGV for --tag options that indicate isolated backend testing
          ARGV.each_with_index do |arg, i|
            tag_value = nil
            if arg == "--tag" && ARGV[i + 1]
              tag_str = ARGV[i + 1]
              next if tag_str.start_with?("~")
              tag_value = tag_str.to_sym
            elsif arg.start_with?("--tag=")
              tag_str = arg.sub("--tag=", "")
              next if tag_str.start_with?("~")
              tag_value = tag_str.to_sym
            end

            next unless tag_value

            # Check for standard backend tags (e.g., :ffi_backend)
            TreeHaver::Backends::BLOCKED_BY.each do |backend, blockers|
              standard_tag = :"#{backend}_backend"
              legacy_tag = :"#{backend}_backend_only"
              if tag_value == standard_tag || tag_value == legacy_tag
                blockers.each { |blocker| blocked << blocker }
              end
            end
          end

          blocked
        end

        # Get a summary of available dependencies (for debugging)
        #
        # This method respects blocked_backends to avoid loading backends
        # that would conflict with isolated test modes (e.g., FFI-only tests).
        #
        # @return [Hash{Symbol => Boolean}] map of dependency name to availability
        def summary
          # Use stored blocked_backends if available, otherwise compute dynamically
          blocked = @blocked_backends || compute_blocked_backends

          {
            # Backend selection from environment variables
            selected_backend: selected_backend,
            allowed_native_backends: allowed_native_backends,
            allowed_ruby_backends: allowed_ruby_backends,
            # TreeHaver backends (*_backend) - skip blocked backends to avoid loading them
            ffi_backend: blocked.include?(:ffi) ? :blocked : ffi_available?,
            mri_backend: blocked.include?(:mri) ? :blocked : mri_backend_available?,
            rust_backend: blocked.include?(:rust) ? :blocked : rust_backend_available?,
            java_backend: blocked.include?(:java) ? :blocked : java_backend_available?,
            prism_backend: blocked.include?(:prism) ? :blocked : prism_available?,
            psych_backend: blocked.include?(:psych) ? :blocked : psych_available?,
            commonmarker_backend: blocked.include?(:commonmarker) ? :blocked : commonmarker_available?,
            markly_backend: blocked.include?(:markly) ? :blocked : markly_available?,
            citrus_backend: blocked.include?(:citrus) ? :blocked : citrus_available?,
            parslet_backend: blocked.include?(:parslet) ? :blocked : parslet_available?,
            rbs_backend: blocked.include?(:rbs) ? :blocked : rbs_backend_available?,
            # Ruby engines (*_engine)
            ruby_engine: RUBY_ENGINE,
            mri_engine: mri?,
            jruby_engine: jruby?,
            truffleruby_engine: truffleruby?,
            # Tree-sitter grammars (*_grammar) - also respect blocked backends
            # since grammar checks may load backends
            libtree_sitter: libtree_sitter_available?,
            bash_grammar: blocked.include?(:mri) ? :blocked : tree_sitter_bash_available?,
            toml_grammar: blocked.include?(:mri) ? :blocked : tree_sitter_toml_available?,
            json_grammar: blocked.include?(:mri) ? :blocked : tree_sitter_json_available?,
            jsonc_grammar: blocked.include?(:mri) ? :blocked : tree_sitter_jsonc_available?,
            rbs_grammar: blocked.include?(:mri) ? :blocked : tree_sitter_rbs_available?,
            any_native_grammar: blocked.include?(:mri) ? :blocked : any_native_grammar_available?,
            # Language parsing capabilities (*_parsing)
            toml_parsing: any_toml_backend_available?,
            markdown_parsing: any_markdown_backend_available?,
            rbs_parsing: any_rbs_backend_available?,
            # Specific libraries (*_gem)
            toml_rb_gem: toml_rb_gem_available?,
            toml_gem: toml_gem_available?,
            rbs_gem: rbs_gem_available?,
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
            "TREE_SITTER_RBS_PATH" => ENV["TREE_SITTER_RBS_PATH"],
            "TREE_SITTER_RUNTIME_LIB" => ENV["TREE_SITTER_RUNTIME_LIB"],
            "TREE_HAVER_BACKEND" => ENV["TREE_HAVER_BACKEND"],
            "TREE_HAVER_DEBUG" => ENV["TREE_HAVER_DEBUG"],
            # Library paths used by tree-sitter shared libraries
            "LD_LIBRARY_PATH" => ENV["LD_LIBRARY_PATH"],
            "DYLD_LIBRARY_PATH" => ENV["DYLD_LIBRARY_PATH"],
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
            # Don't reset ENV-based values
            next if %i[@selected_backend @allowed_native_backends @allowed_ruby_backends].include?(ivar)
            remove_instance_variable(ivar) if ivar.to_s.end_with?("_available")
          end
        end

        # Reset selected backend caches (useful for testing with different ENV values)
        #
        # Also resets TreeHaver's backend caches.
        #
        # @return [void]
        def reset_selected_backend!
          remove_instance_variable(:@selected_backend) if defined?(@selected_backend)
          remove_instance_variable(:@allowed_native_backends) if defined?(@allowed_native_backends)
          remove_instance_variable(:@allowed_ruby_backends) if defined?(@allowed_ruby_backends)
          TreeHaver.reset_backend!
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

  # ============================================================
  # Backend Protection for Test Suites
  # ============================================================
  #
  # TreeHaver protects against backend conflicts by default (e.g., FFI cannot
  # be used after MRI has been loaded because it would cause a segfault).
  # This protection remains enabled in test suites to prevent crashes.
  #
  # If you need to test multiple incompatible backends in the same process
  # (accepting the risk of segfaults), you can disable protection:
  #   TREE_HAVER_BACKEND_PROTECT=false bundle exec rspec
  #
  # Note: The recommended approach is to run separate test processes for
  # incompatible backends using RSpec tags or separate CI jobs.
  if ENV["TREE_HAVER_BACKEND_PROTECT"] == "false"
    TreeHaver.backend_protect = false
  end

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

  # FFI backend exclusion:
  # If MRI has already been used, FFI is blocked and will never be available.
  # In this case, exclude FFI tests tagged with :ffi_backend entirely rather than
  # showing them as pending.
  #
  # NOTE: We do NOT exclude :ffi_backend_only here because the Rakefile uses
  # `--tag ~ffi_backend_only` for the remaining_specs task. RSpec interprets
  # `--tag ~X` as an include filter with key "~X", which conflicts with
  # filter_run_excluding. Instead, :ffi_backend_only tests will be skipped
  # via the before(:each) hook below when FFI is not available.
  if TreeHaver.backends_used.include?(:mri)
    config.filter_run_excluding(ffi_backend: true)
  end

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
    parslet: :parslet_available?,
    rbs: :rbs_backend_available?,
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
    parslet: :parslet_backend,
    rbs: :rbs_backend,
  }

  # Determine which backends should NOT have availability checked
  # based on which *_backend_only tag is being run OR which backend is
  # explicitly selected via TREE_HAVER_BACKEND environment variable.
  blocked_backends = Set.new

  # Track whether we're in isolated test mode (running *_backend_only tags).
  # This is different from just having TREE_HAVER_BACKEND set.
  # In isolated mode, we skip ALL grammar checks because they might trigger
  # backend loading via TreeHaver.parser_for's auto-detection.
  # When just TREE_HAVER_BACKEND is set, grammar checks are fine because
  # parser_for will use the selected backend, not auto-detect.
  isolated_test_mode = false

  # First, check if TREE_HAVER_BACKEND explicitly selects a backend.
  # If so, block all backends that would conflict with it.
  # This prevents loading MRI when TREE_HAVER_BACKEND=ffi, for example.
  env_backend = ENV["TREE_HAVER_BACKEND"]
  if env_backend && !env_backend.empty? && env_backend != "auto"
    backend_sym = env_backend.to_sym
    TreeHaver::Backends::BLOCKED_BY[backend_sym]&.each { |blocker| blocked_backends << blocker }
  end

  # Check which *_backend_only tags are being run and block their conflicting backends
  # config.inclusion_filter contains tags passed via --tag on command line
  inclusion_rules = config.inclusion_filter.rules

  # If filter.rules is empty, check ARGV directly for --tag options
  # This handles the case where RSpec hasn't processed filters yet during configuration
  if inclusion_rules.empty?
    ARGV.each_with_index do |arg, i|
      if arg == "--tag" && ARGV[i + 1]
        tag_str = ARGV[i + 1]
        # Skip exclusion tags (prefixed with ~) - they are NOT inclusion filters
        next if tag_str.start_with?("~")
        tag_value = tag_str.to_sym
        inclusion_rules[tag_value] = true
      elsif arg.start_with?("--tag=")
        tag_str = arg.sub("--tag=", "")
        # Skip exclusion tags (prefixed with ~) - they are NOT inclusion filters
        next if tag_str.start_with?("~")
        tag_value = tag_str.to_sym
        inclusion_rules[tag_value] = true
      end
    end
  end

  # Check if we're running isolated backend tests using standard backend tags
  # When running with --tag ffi_backend (or other native backend tags), we need
  # to block conflicting backends to prevent them from loading first.
  # This replaces the old *_backend_only pattern with the standard *_backend tags.
  TreeHaver::Backends::BLOCKED_BY.each do |backend, blockers|
    # Check if we're running this backend's tests using standard tag (e.g., :ffi_backend)
    standard_tag = :"#{backend}_backend"
    if inclusion_rules[standard_tag]
      isolated_test_mode = true
      # Add all backends that would block this one
      blockers.each { |blocker| blocked_backends << blocker }
    end

    # Also support legacy *_backend_only tags for backwards compatibility
    legacy_tag = :"#{backend}_backend_only"
    if inclusion_rules[legacy_tag]
      isolated_test_mode = true
      blockers.each { |blocker| blocked_backends << blocker }
    end
  end

  # Store blocked_backends in a module variable so before(:suite) can access it
  TreeHaver::RSpec::DependencyTags.instance_variable_set(:@blocked_backends, blocked_backends)
  TreeHaver::RSpec::DependencyTags.instance_variable_set(:@isolated_test_mode, isolated_test_mode)

  # Now configure exclusions, skipping availability checks for blocked backends
  backend_tags.each do |backend, tag|
    # FFI is handled specially with before(:each) hook above
    next if backend == :ffi

    # If this backend is in blocked_backends, we exclude its tests WITHOUT checking
    # availability. This prevents loading a conflicting backend while still ensuring
    # tests for unavailable backends are skipped.
    if blocked_backends.include?(backend)
      config.filter_run_excluding(tag => true)
      next
    end

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
  #   :bash_grammar, :toml_grammar, :json_grammar, :jsonc_grammar, :rbs_grammar
  #
  # Also: :libtree_sitter - requires the libtree-sitter runtime library
  #
  # NOTE: When running with *_backend_only tags, we skip these checks to avoid
  # loading blocked backends. The grammar checks use TreeHaver.parser_for which
  # would load the default backend (MRI) and block FFI.

  # Skip grammar availability checks only when in isolated test mode.
  # When TREE_HAVER_BACKEND is explicitly set (but not using *_backend_only tags),
  # grammar checks are fine because TreeHaver.parser_for respects the env var.
  unless isolated_test_mode
    config.filter_run_excluding(libtree_sitter: true) unless deps.libtree_sitter_available?
    config.filter_run_excluding(bash_grammar: true) unless deps.tree_sitter_bash_available?
    config.filter_run_excluding(toml_grammar: true) unless deps.tree_sitter_toml_available?
    config.filter_run_excluding(json_grammar: true) unless deps.tree_sitter_json_available?
    config.filter_run_excluding(jsonc_grammar: true) unless deps.tree_sitter_jsonc_available?
    config.filter_run_excluding(rbs_grammar: true) unless deps.tree_sitter_rbs_available?
  end

  # ============================================================
  # Language Parsing Capability Tags
  # ============================================================
  # Tags: *_parsing - require ANY parser for a language (any backend that can parse it)
  #   :toml_parsing   - any TOML parser (tree-sitter-toml OR toml-rb/Citrus)
  #   :markdown_parsing - any Markdown parser (commonmarker OR markly)
  #   :rbs_parsing    - any RBS parser (rbs gem OR tree-sitter-rbs)
  #   :native_parsing - any native tree-sitter backend + grammar
  #
  # NOTE: any_toml_backend_available? calls tree_sitter_toml_available? which
  # triggers grammar_works? and loads MRI. Skip when running isolated tests.

  unless isolated_test_mode
    config.filter_run_excluding(toml_parsing: true) unless deps.any_toml_backend_available?
    config.filter_run_excluding(markdown_parsing: true) unless deps.any_markdown_backend_available?
    config.filter_run_excluding(rbs_parsing: true) unless deps.any_rbs_backend_available?
    config.filter_run_excluding(native_parsing: true) unless deps.any_native_grammar_available?
  end

  # ============================================================
  # Specific Library Tags
  # ============================================================
  # Tags for specific gems/libraries (*_gem suffix)
  #   :toml_rb_gem - the toml-rb gem (Citrus-based TOML parser)
  #   :rbs_gem - the rbs gem (official RBS parser, MRI only)
  #   Note: :rbs_backend is also available as an alias for :rbs_gem

  config.filter_run_excluding(toml_rb_gem: true) unless deps.toml_rb_gem_available?
  config.filter_run_excluding(rbs_gem: true) unless deps.rbs_gem_available?


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
  unless isolated_test_mode
    config.filter_run_excluding(not_libtree_sitter: true) if deps.libtree_sitter_available?
    config.filter_run_excluding(not_bash_grammar: true) if deps.tree_sitter_bash_available?
    config.filter_run_excluding(not_toml_grammar: true) if deps.tree_sitter_toml_available?
    config.filter_run_excluding(not_json_grammar: true) if deps.tree_sitter_json_available?
    config.filter_run_excluding(not_jsonc_grammar: true) if deps.tree_sitter_jsonc_available?
    config.filter_run_excluding(not_rbs_grammar: true) if deps.tree_sitter_rbs_available?

    # Language parsing capabilities
    config.filter_run_excluding(not_toml_parsing: true) if deps.any_toml_backend_available?
    config.filter_run_excluding(not_markdown_parsing: true) if deps.any_markdown_backend_available?
    config.filter_run_excluding(not_rbs_parsing: true) if deps.any_rbs_backend_available?
  end

  # Specific libraries
  config.filter_run_excluding(not_toml_rb_gem: true) if deps.toml_rb_gem_available?
  config.filter_run_excluding(not_rbs_gem: true) if deps.rbs_gem_available?
end
