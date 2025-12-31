# frozen_string_literal: true

# External gems
require "version_gem"

# Standard library
require "set"

# This gem - only version can be required (never autoloaded)
require_relative "tree_haver/version"

# TreeHaver is a cross-Ruby adapter for code parsing with 10 backends.
#
# Provides a unified API for parsing source code across MRI Ruby, JRuby, and TruffleRuby
# using tree-sitter grammars or language-specific native parsers.
#
# == Backends
#
# Supports 10 backends:
# - Tree-sitter: MRI (C), Rust, FFI, Java
# - Native parsers: Prism (Ruby), Psych (YAML), Commonmarker (Markdown), Markly (GFM)
# - Pure Ruby: Citrus (portable fallback)
#
# == Platform Compatibility
#
# Not all backends work on all Ruby platforms:
#
#   | Backend      | MRI | JRuby | TruffleRuby |
#   |--------------|-----|-------|-------------|
#   | MRI (C ext)  | ✓   | ✗     | ✗           |
#   | Rust         | ✓   | ✗     | ✗           |
#   | FFI          | ✓   | ✓     | ✗           |
#   | Java         | ✗   | ✓     | ✗           |
#   | Prism        | ✓   | ✓     | ✓           |
#   | Psych        | ✓   | ✓     | ✓           |
#   | Citrus       | ✓   | ✓     | ✓           |
#   | Commonmarker | ✓   | ✗     | ?           |
#   | Markly       | ✓   | ✗     | ?           |
#
# - JRuby: Cannot load native C/Rust extensions; use FFI, Java, or pure Ruby backends
# - TruffleRuby: FFI doesn't support STRUCT_BY_VALUE; magnus/rb-sys incompatible with C API;
#   use Prism, Psych, Citrus, or potentially Commonmarker/Markly
#
# @example Basic usage with tree-sitter
#   # Load a language grammar
#   language = TreeHaver::Language.from_library(
#     "/usr/local/lib/libtree-sitter-toml.so",
#     symbol: "tree_sitter_toml"
#   )
#
#   # Create and configure a parser
#   parser = TreeHaver::Parser.new
#   parser.language = language
#
#   # Parse source code
#   tree = parser.parse("[package]\nname = \"my-app\"")
#   root = tree.root_node
#
#   # Use unified Position API (works across all backends)
#   puts root.start_line      # => 1 (1-based)
#   puts root.source_position # => {start_line:, end_line:, start_column:, end_column:}
#
# @example Using language-specific backends
#   # Parse Ruby with Prism
#   TreeHaver.backend = :prism
#   parser = TreeHaver::Parser.new
#   parser.language = TreeHaver::Backends::Prism::Language.ruby
#   tree = parser.parse("class Example; end")
#
#   # Parse YAML with Psych
#   TreeHaver.backend = :psych
#   parser = TreeHaver::Parser.new
#   parser.language = TreeHaver::Backends::Psych::Language.yaml
#   tree = parser.parse("key: value")
#
#   # Parse Markdown with Commonmarker
#   TreeHaver.backend = :commonmarker
#   parser = TreeHaver::Parser.new
#   parser.language = TreeHaver::Backends::Commonmarker::Language.markdown
#   tree = parser.parse("# Heading\nParagraph")
#
# @example Using language registration
#   TreeHaver.register_language(:toml, path: "/usr/local/lib/libtree-sitter-toml.so")
#   language = TreeHaver::Language.toml
#
# @example Using GrammarFinder for automatic discovery
#   # GrammarFinder automatically locates grammar libraries on the system
#   finder = TreeHaver::GrammarFinder.new(:toml)
#   finder.register! if finder.available?
#   language = TreeHaver::Language.toml
#
# @example Selecting a backend
#   TreeHaver.backend = :mri          # Force MRI (ruby_tree_sitter)
#   TreeHaver.backend = :rust         # Force Rust (tree_stump)
#   TreeHaver.backend = :ffi          # Force FFI
#   TreeHaver.backend = :java         # Force Java (JRuby)
#   TreeHaver.backend = :prism        # Force Prism (Ruby)
#   TreeHaver.backend = :psych        # Force Psych (YAML)
#   TreeHaver.backend = :commonmarker # Force Commonmarker (Markdown)
#   TreeHaver.backend = :markly       # Force Markly (GFM)
#   TreeHaver.backend = :citrus       # Force Citrus (pure Ruby)
#   TreeHaver.backend = :auto         # Auto-select (default)
#
# @see https://tree-sitter.github.io/tree-sitter/ tree-sitter documentation
# @see GrammarFinder For automatic grammar library discovery
# @see Backends For available parsing backends
module TreeHaver
  # Autoload internal modules
  autoload :LibraryPathUtils, File.join(__dir__, "tree_haver", "library_path_utils")
  autoload :LanguageRegistry, File.join(__dir__, "tree_haver", "language_registry")

  # Base error class for TreeHaver exceptions
  # @see https://github.com/Faveod/ruby-tree-sitter/pull/83 for inherit from Exception reasoning
  #
  # @abstract Subclass to create specific error types
  class Error < Exception; end  # rubocop:disable Lint/InheritException

  # Raised when a requested backend or feature is not available
  # These are serious errors that extends Exception (not StandardError).
  # @see https://github.com/Faveod/ruby-tree-sitter/pull/83 for inherit from Exception reasoning
  #
  # This can occur when:
  # - Required native libraries are not installed
  # - The selected backend is not compatible with the current Ruby implementation
  # - A language grammar cannot be loaded
  #
  # @example Handling unavailable backends
  #   begin
  #     language = TreeHaver::Language.from_library("/path/to/grammar.so")
  #   rescue TreeHaver::NotAvailable => e
  #     puts "Grammar not available: #{e.message}"
  #   end
  class NotAvailable < Error; end

  # Raised when attempting to use backends that are known to conflict
  #
  # This is a serious error that extends Exception (not StandardError) because
  # it prevents a segmentation fault. The MRI backend (ruby_tree_sitter) and
  # FFI backend cannot coexist in the same process - once MRI loads, FFI will
  # segfault when trying to set a language on a parser.
  #
  # This protection can be disabled with `TreeHaver.backend_protect = false`
  # but doing so risks segfaults.
  #
  # @example Handling backend conflicts
  #   begin
  #     # This will raise if MRI was already used
  #     TreeHaver.with_backend(:ffi) { parser.language = lang }
  #   rescue TreeHaver::BackendConflict => e
  #     puts "Backend conflict: #{e.message}"
  #     # Fall back to a compatible backend
  #   end
  #
  # @example Disabling protection (not recommended)
  #   TreeHaver.backend_protect = false
  #   # Now you can test backend conflicts (at risk of segfaults)
  class BackendConflict < Error; end

  # Default Citrus configurations for known languages
  #
  # These are used by {TreeHaver.parser_for} when no explicit citrus_config is provided
  # and tree-sitter backends are not available (e.g., on TruffleRuby).
  #
  # @api private
  CITRUS_DEFAULTS = {
    toml: {
      gem_name: "toml-rb",
      grammar_const: "TomlRB::Document",
      require_path: "toml-rb",
    },
  }.freeze

  # Namespace for backend implementations
  #
  # TreeHaver provides multiple backends to support different Ruby implementations:
  # - {Backends::MRI} - Uses ruby_tree_sitter (MRI C extension)
  # - {Backends::Rust} - Uses tree_stump (Rust extension with precompiled binaries)
  # - {Backends::FFI} - Uses Ruby FFI to call libtree-sitter directly
  # - {Backends::Java} - Uses JRuby's Java integration
  # - {Backends::Citrus} - Uses Citrus PEG parser (pure Ruby, portable)
  # - {Backends::Prism} - Uses Ruby's built-in Prism parser (Ruby-only, stdlib in 3.4+)
  module Backends
    autoload :MRI, File.join(__dir__, "tree_haver", "backends", "mri")
    autoload :Rust, File.join(__dir__, "tree_haver", "backends", "rust")
    autoload :FFI, File.join(__dir__, "tree_haver", "backends", "ffi")
    autoload :Java, File.join(__dir__, "tree_haver", "backends", "java")
    autoload :Citrus, File.join(__dir__, "tree_haver", "backends", "citrus")
    autoload :Prism, File.join(__dir__, "tree_haver", "backends", "prism")
    autoload :Psych, File.join(__dir__, "tree_haver", "backends", "psych")
    autoload :Commonmarker, File.join(__dir__, "tree_haver", "backends", "commonmarker")
    autoload :Markly, File.join(__dir__, "tree_haver", "backends", "markly")

    # Known backend conflicts
    #
    # Maps each backend to an array of backends that block it from working.
    # For example, :ffi is blocked by :mri because once ruby_tree_sitter loads,
    # FFI calls to ts_parser_set_language will segfault.
    #
    # @return [Hash{Symbol => Array<Symbol>}]
    BLOCKED_BY = {
      mri: [],
      rust: [],
      ffi: [:mri],  # FFI segfaults if MRI (ruby_tree_sitter) has been loaded
      java: [],
      citrus: [],
      prism: [],        # Prism has no conflicts with other backends
      psych: [],        # Psych has no conflicts with other backends
      commonmarker: [], # Commonmarker has no conflicts with other backends
      markly: [],       # Markly has no conflicts with other backends
    }.freeze
  end

  # Security utilities for validating paths before loading shared libraries
  #
  # @example Validate a path
  #   TreeHaver::PathValidator.safe_library_path?("/usr/lib/libtree-sitter-toml.so")
  #   # => true
  #
  # @see PathValidator
  autoload :PathValidator, File.join(__dir__, "tree_haver", "path_validator")

  # Generic grammar finder utility with built-in security validations
  #
  # GrammarFinder provides platform-aware discovery of tree-sitter grammar
  # libraries for any language. It validates paths from environment variables
  # to prevent path traversal and other attacks.
  #
  # @example Find and register a language
  #   finder = TreeHaver::GrammarFinder.new(:toml)
  #   finder.register! if finder.available?
  #   language = TreeHaver::Language.toml
  #
  # @example Secure mode (trusted directories only)
  #   finder = TreeHaver::GrammarFinder.new(:toml)
  #   path = finder.find_library_path_safe  # Ignores ENV, only trusted dirs
  #
  # @see GrammarFinder
  # @see PathValidator
  autoload :GrammarFinder, File.join(__dir__, "tree_haver", "grammar_finder")

  # Citrus grammar finder for discovering and registering Citrus-based parsers
  #
  # @example Register toml-rb
  #   finder = TreeHaver::CitrusGrammarFinder.new(
  #     language: :toml,
  #     gem_name: "toml-rb",
  #     grammar_const: "TomlRB::Document"
  #   )
  #   finder.register! if finder.available?
  #
  # @see CitrusGrammarFinder
  autoload :CitrusGrammarFinder, File.join(__dir__, "tree_haver", "citrus_grammar_finder")

  # Point class for position information (row, column)
  autoload :Point, File.join(__dir__, "tree_haver", "point")

  # Unified Node wrapper providing consistent API across backends
  autoload :Node, File.join(__dir__, "tree_haver", "node")

  # Unified Tree wrapper providing consistent API across backends
  autoload :Tree, File.join(__dir__, "tree_haver", "tree")

  # Language class for loading grammar shared libraries
  autoload :Language, File.join(__dir__, "tree_haver", "language")

  # Parser class for parsing source code into syntax trees
  autoload :Parser, File.join(__dir__, "tree_haver", "parser")

  # Get the current backend selection
  #
  # @return [Symbol] one of :auto, :mri, :rust, :ffi, :java, or :citrus
  # @note Can be set via ENV["TREE_HAVER_BACKEND"]
  class << self
    # Whether backend conflict protection is enabled
    #
    # When true (default), TreeHaver will raise BackendConflict if you try to
    # use a backend that is known to conflict with a previously used backend.
    # For example, FFI will not work after MRI has been used.
    #
    # Set to false to disable protection (useful for testing compatibility).
    #
    # @return [Boolean]
    # @example Disable protection for testing
    #   TreeHaver.backend_protect = false
    def backend_protect=(value)
      @backend_protect_mutex ||= Mutex.new
      @backend_protect_mutex.synchronize { @backend_protect = value }
    end

    # Check if backend conflict protection is enabled
    #
    # @return [Boolean] true if protection is enabled (default)
    def backend_protect?
      return @backend_protect if defined?(@backend_protect) # rubocop:disable ThreadSafety/ClassInstanceVariable
      true  # Default is protected
    end

    # Alias for backend_protect?
    def backend_protect
      backend_protect?
    end

    # Track which backends have been used in this process
    #
    # @return [Set<Symbol>] set of backend symbols that have been used
    def backends_used
      @backends_used ||= Set.new # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    # Record that a backend has been used
    #
    # @param backend [Symbol] the backend that was used
    # @return [void]
    # @api private
    def record_backend_usage(backend)
      backends_used << backend
    end

    # Check if a backend would conflict with previously used backends
    #
    # @param backend [Symbol] the backend to check
    # @return [Array<Symbol>] list of previously used backends that block this one
    def conflicting_backends_for(backend)
      blockers = Backends::BLOCKED_BY[backend] || []
      blockers & backends_used.to_a
    end

    # Check if using a backend would cause a conflict
    #
    # @param backend [Symbol] the backend to check
    # @raise [BackendConflict] if protection is enabled and there's a conflict
    # @return [void]
    def check_backend_conflict!(backend)
      return unless backend_protect?

      conflicts = conflicting_backends_for(backend)
      return if conflicts.empty?

      raise BackendConflict,
        "Cannot use #{backend} backend: it is blocked by previously used backend(s): #{conflicts.join(", ")}. " \
          "The #{backend} backend will segfault when #{conflicts.first} has already loaded. " \
          "To disable this protection (at risk of segfaults), set TreeHaver.backend_protect = false"
    end

    # @example
    #   TreeHaver.backend  # => :auto
    def backend
      @backend ||= case (ENV["TREE_HAVER_BACKEND"] || :auto).to_s # rubocop:disable ThreadSafety/ClassInstanceVariable
      when "mri" then :mri
      when "rust" then :rust
      when "ffi" then :ffi
      when "java" then :java
      when "citrus" then :citrus
      when "prism" then :prism
      when "psych" then :psych
      when "commonmarker" then :commonmarker
      when "markly" then :markly
      else :auto
      end
    end

    # Set the backend to use
    #
    # @param name [Symbol, String, nil] backend name (:auto, :mri, :rust, :ffi, :java, :citrus)
    # @return [Symbol, nil] the backend that was set
    # @example Force FFI backend
    #   TreeHaver.backend = :ffi
    # @example Force Rust backend
    #   TreeHaver.backend = :rust
    def backend=(name)
      @backend = name&.to_sym # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    # Reset backend selection memoization
    #
    # Primarily useful in tests to switch backends without cross-example leakage.
    #
    # @param to [Symbol, String, nil] backend name or nil to clear (defaults to :auto)
    # @return [void]
    # @example Reset to auto-selection
    #   TreeHaver.reset_backend!
    # @example Reset to specific backend
    #   TreeHaver.reset_backend!(to: :ffi)
    def reset_backend!(to: :auto)
      @backend = to&.to_sym # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    # Thread-local backend context storage
    #
    # Returns a hash containing the thread-local backend context with keys:
    # - :backend - The backend name (Symbol) or nil if using global default
    # - :depth - The nesting depth (Integer) for proper cleanup
    #
    # @return [Hash{Symbol => Object}] context hash with :backend and :depth keys
    # @example
    #   ctx = TreeHaver.current_backend_context
    #   ctx[:backend]  # => nil or :ffi, :mri, etc.
    #   ctx[:depth]    # => 0, 1, 2, etc.
    def current_backend_context
      Thread.current[:tree_haver_backend_context] ||= {
        backend: nil,  # nil means "use global default"
        depth: 0,       # Track nesting depth for proper cleanup
      }
    end

    # Get the effective backend for current context
    #
    # Priority: thread-local context → global @backend → :auto
    #
    # @return [Symbol] the backend to use
    # @example
    #   TreeHaver.effective_backend  # => :auto (default)
    # @example With thread-local context
    #   TreeHaver.with_backend(:ffi) do
    #     TreeHaver.effective_backend  # => :ffi
    #   end
    def effective_backend
      ctx = current_backend_context
      ctx[:backend] || backend || :auto
    end

    # Execute a block with a specific backend in thread-local context
    #
    # This method provides temporary, thread-safe backend switching for a block of code.
    # The backend setting is automatically restored when the block exits, even if
    # an exception is raised. Supports nesting—inner blocks override outer blocks,
    # and each level is properly unwound.
    #
    # Thread Safety: Each thread maintains its own backend context, so concurrent
    # threads can safely use different backends without interfering with each other.
    #
    # Use Cases:
    # - Testing: Test the same code path with different backends
    # - Performance comparison: Benchmark parsing with different backends
    # - Fallback scenarios: Try one backend, fall back to another on failure
    # - Thread isolation: Different threads can use different backends safely
    #
    # @param name [Symbol, String] backend name (:mri, :rust, :ffi, :java, :citrus, :auto)
    # @yield block to execute with the specified backend
    # @return [Object] the return value of the block
    # @raise [ArgumentError] if backend name is nil
    # @raise [BackendConflict] if the requested backend conflicts with a previously used backend
    #
    # @example Basic usage
    #   TreeHaver.with_backend(:mri) do
    #     parser = TreeHaver::Parser.new
    #     tree = parser.parse(source)
    #   end
    #   # Backend is automatically restored here
    #
    # @example Nested blocks (inner overrides outer)
    #   TreeHaver.with_backend(:rust) do
    #     parser1 = TreeHaver::Parser.new  # Uses :rust
    #     TreeHaver.with_backend(:citrus) do
    #       parser2 = TreeHaver::Parser.new  # Uses :citrus
    #     end
    #     parser3 = TreeHaver::Parser.new  # Back to :rust
    #   end
    #
    # @example Testing multiple backends
    #   [:mri, :rust, :citrus].each do |backend_name|
    #     TreeHaver.with_backend(backend_name) do
    #       parser = TreeHaver::Parser.new
    #       result = parser.parse(source)
    #       puts "#{backend_name}: #{result.root_node.type}"
    #     end
    #   end
    #
    # @example Exception safety (backend restored even on error)
    #   TreeHaver.with_backend(:mri) do
    #     raise "Something went wrong"
    #   rescue
    #     # Handle error
    #   end
    #   # Backend is still restored to its previous value
    #
    # @example Thread isolation
    #   threads = [:mri, :rust].map do |backend_name|
    #     Thread.new do
    #       TreeHaver.with_backend(backend_name) do
    #         # Each thread uses its own backend independently
    #         TreeHaver::Parser.new
    #       end
    #     end
    #   end
    #   threads.each(&:join)
    #
    # @see #effective_backend
    # @see #current_backend_context
    def with_backend(name)
      raise ArgumentError, "Backend name required" if name.nil?

      # Get context FIRST to ensure it exists
      ctx = current_backend_context
      old_backend = ctx[:backend]
      old_depth = ctx[:depth]

      begin
        # Set new backend and increment depth
        ctx[:backend] = name.to_sym
        ctx[:depth] += 1

        # Execute block
        yield
      ensure
        # Restore previous backend and depth
        # This ensures proper unwinding even with exceptions
        ctx[:backend] = old_backend
        ctx[:depth] = old_depth
      end
    end

    # Resolve the effective backend considering explicit override
    #
    # Priority: explicit > thread context > global > :auto
    #
    # @param explicit_backend [Symbol, String, nil] explicitly requested backend
    # @return [Symbol] the backend to use
    # @example
    #   TreeHaver.resolve_effective_backend(:ffi)  # => :ffi
    # @example With thread-local context
    #   TreeHaver.with_backend(:mri) do
    #     TreeHaver.resolve_effective_backend(nil)  # => :mri
    #     TreeHaver.resolve_effective_backend(:ffi)  # => :ffi (explicit wins)
    #   end
    def resolve_effective_backend(explicit_backend = nil)
      return explicit_backend.to_sym if explicit_backend
      effective_backend
    end

    # Get backend module for a specific backend (with explicit override)
    #
    # @param explicit_backend [Symbol, String, nil] explicitly requested backend
    # @return [Module, nil] the backend module or nil if not available
    # @raise [BackendConflict] if the backend conflicts with previously used backends
    # @example
    #   mod = TreeHaver.resolve_backend_module(:ffi)
    #   mod.capabilities[:backend]  # => :ffi
    def resolve_backend_module(explicit_backend = nil)
      # Temporarily override effective backend
      requested = resolve_effective_backend(explicit_backend)

      mod = case requested
      when :mri
        Backends::MRI
      when :rust
        Backends::Rust
      when :ffi
        Backends::FFI
      when :java
        Backends::Java
      when :citrus
        Backends::Citrus
      when :prism
        Backends::Prism
      when :psych
        Backends::Psych
      when :commonmarker
        Backends::Commonmarker
      when :markly
        Backends::Markly
      when :auto
        backend_module  # Fall back to normal resolution for :auto
      else
        # Unknown backend name - return nil to trigger error in caller
        nil
      end

      # Return nil if the module doesn't exist
      return unless mod

      # Check for backend conflicts FIRST, before checking availability
      # This is critical because the conflict causes the backend to report unavailable
      # We want to raise a clear error explaining WHY it's unavailable
      # Use the requested backend name directly (not capabilities) because
      # capabilities may be empty when the backend is blocked/unavailable
      check_backend_conflict!(requested) if requested && requested != :auto

      # Now check if the backend is available
      # Why assume modules without available? are available?
      # - Some backends might be mocked in tests without an available? method
      # - This makes the code more defensive and test-friendly
      # - It allows graceful degradation if a backend module is incomplete
      # - Backward compatibility: if a module doesn't declare availability, assume it works
      return if mod.respond_to?(:available?) && !mod.available?

      # Record that this backend is being used
      record_backend_usage(requested) if requested && requested != :auto

      mod
    end

    # Native tree-sitter backends that support loading shared libraries (.so files)
    # These backends wrap the tree-sitter C library via various bindings.
    # Pure Ruby backends (Citrus, Prism, Psych, Commonmarker, Markly) are excluded.
    NATIVE_BACKENDS = %i[mri rust ffi java].freeze

    # Resolve a native tree-sitter backend module (for from_library)
    #
    # This method is similar to resolve_backend_module but ONLY considers
    # backends that support loading shared libraries (.so files):
    # - MRI (ruby_tree_sitter C extension)
    # - Rust (tree_stump)
    # - FFI (ffi gem with libtree-sitter)
    # - Java (jtreesitter on JRuby)
    #
    # Pure Ruby backends (Citrus, Prism, Psych, Commonmarker, Markly) are NOT
    # considered because they don't support from_library.
    #
    # @param explicit_backend [Symbol, String, nil] explicitly requested backend
    # @return [Module, nil] the backend module or nil if none available
    # @raise [BackendConflict] if the backend conflicts with previously used backends
    def resolve_native_backend_module(explicit_backend = nil)
      # Short-circuit on TruffleRuby: no native backends work
      # - MRI: C extension, MRI only
      # - Rust: magnus requires MRI's C API
      # - FFI: STRUCT_BY_VALUE not supported
      # - Java: requires JRuby's Java interop
      if defined?(RUBY_ENGINE) && RUBY_ENGINE == "truffleruby"
        return unless explicit_backend # Auto-select: no backends available
        # If explicit backend requested, let it fail with proper error below
      end

      # Get the effective backend (considers thread-local and global settings)
      requested = resolve_effective_backend(explicit_backend)

      # If the effective backend is a native backend, use it
      if NATIVE_BACKENDS.include?(requested)
        return resolve_backend_module(requested)
      end

      # If a specific non-native backend was explicitly requested, return nil
      # (from_library only works with native backends that load .so files)
      return if explicit_backend

      # If effective backend is :auto, auto-select from native backends in priority order
      # Note: non-native backends set via with_backend are NOT used here because
      # from_library only works with native backends
      native_priority = if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
        %i[java ffi] # JRuby: Java first, then FFI
      else
        %i[mri rust ffi] # MRI: MRI first, then Rust, then FFI
      end

      native_priority.each do |backend|
        mod = resolve_backend_module(backend)
        return mod if mod
      end

      nil # No native backend available
    end

    # Determine the concrete backend module to use
    #
    # This method performs backend auto-selection when backend is :auto.
    # On JRuby, prefers Java backend if available, then FFI, then Citrus.
    # On MRI, prefers MRI backend if available, then Rust, then FFI, then Citrus.
    # Citrus is the final fallback as it's pure Ruby and works everywhere.
    #
    # @return [Module, nil] the backend module (Backends::MRI, Backends::Rust, Backends::FFI, Backends::Java, or Backends::Citrus), or nil if none available
    # @example
    #   mod = TreeHaver.backend_module
    #   if mod
    #     puts "Using #{mod.capabilities[:backend]} backend"
    #   end
    def backend_module
      case effective_backend  # Changed from: backend
      when :mri
        Backends::MRI
      when :rust
        Backends::Rust
      when :ffi
        Backends::FFI
      when :java
        Backends::Java
      when :citrus
        Backends::Citrus
      when :prism
        Backends::Prism
      when :psych
        Backends::Psych
      when :commonmarker
        Backends::Commonmarker
      when :markly
        Backends::Markly
      else
        # auto-select: prefer native/fast backends, fall back to pure Ruby (Citrus)
        if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby" && Backends::Java.available?
          Backends::Java
        elsif defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby" && Backends::MRI.available?
          Backends::MRI
        elsif defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby" && Backends::Rust.available?
          Backends::Rust
        elsif Backends::FFI.available?
          Backends::FFI
        elsif Backends::Citrus.available?
          Backends::Citrus  # Pure Ruby fallback
        else
          # No backend available
          nil
        end
      end
    end

    # Get capabilities of the current backend
    #
    # Returns a hash describing what features the selected backend supports.
    # Common keys include:
    # - :backend - Symbol identifying the backend (:mri, :rust, :ffi, :java)
    # - :parse - Whether parsing is implemented
    # - :query - Whether the Query API is available
    # - :bytes_field - Whether byte position fields are available
    # - :incremental - Whether incremental parsing is supported
    #
    # @return [Hash{Symbol => Object}] capability map, or empty hash if no backend available
    # @example
    #   TreeHaver.capabilities
    #   # => { backend: :mri, query: true, bytes_field: true }
    def capabilities
      mod = backend_module
      return {} unless mod
      mod.capabilities
    end

    # -- Language registration API -------------------------------------------------
    # Delegates to LanguageRegistry for thread-safe registration and lookup.
    # Allows opting-in dynamic helpers like TreeHaver::Language.toml without
    # advertising all names by default.

    # Register a language helper by name (backend-agnostic)
    #
    # After registration, you can use dynamic helpers like `TreeHaver::Language.toml`
    # to load the registered language. TreeHaver will automatically use the appropriate
    # grammar based on the active backend.
    #
    # The `name` parameter is an arbitrary identifier you choose - it doesn't need to
    # match the actual language name. This is useful for:
    # - Testing: Use unique names like `:toml_test` to avoid collisions
    # - Aliasing: Register the same grammar under multiple names
    # - Versioning: Register different grammar versions as `:ruby_2` and `:ruby_3`
    #
    # The actual grammar identity comes from `path`/`symbol` (tree-sitter) or
    # `grammar_module` (Citrus), not from the name.
    #
    # IMPORTANT: This method INTENTIONALLY allows registering BOTH a tree-sitter
    # library AND a Citrus grammar for the same language IN A SINGLE CALL.
    # This is achieved by using separate `if` statements (not `elsif`) and no early
    # returns. This design is deliberate and provides significant benefits:
    #
    # Why register both backends for one language?
    # - Backend flexibility: Code works regardless of which backend is active
    # - Performance testing: Compare tree-sitter vs Citrus performance
    # - Gradual migration: Transition between backends without breaking code
    # - Fallback scenarios: Use Citrus when tree-sitter library unavailable
    # - Platform portability: tree-sitter on Linux/Mac, Citrus on JRuby/Windows
    #
    # The active backend determines which registration is used automatically.
    # No code changes needed to switch backends - just change TreeHaver.backend.
    #
    # @param name [Symbol, String] identifier for this registration (can be any name you choose)
    # @param path [String, nil] absolute path to the language shared library (for tree-sitter)
    # @param symbol [String, nil] optional exported factory symbol (e.g., "tree_sitter_toml")
    # @param grammar_module [Module, nil] Citrus grammar module that responds to .parse(source)
    # @param gem_name [String, nil] optional gem name for error messages
    # @return [void]
    # @example Register tree-sitter grammar only
    #   TreeHaver.register_language(
    #     :toml,
    #     path: "/usr/local/lib/libtree-sitter-toml.so",
    #     symbol: "tree_sitter_toml"
    #   )
    # @example Register Citrus grammar only
    #   TreeHaver.register_language(
    #     :toml,
    #     grammar_module: TomlRB::Document,
    #     gem_name: "toml-rb"
    #   )
    # @example Register BOTH backends in separate calls
    #   TreeHaver.register_language(
    #     :toml,
    #     path: "/usr/local/lib/libtree-sitter-toml.so",
    #     symbol: "tree_sitter_toml"
    #   )
    #   TreeHaver.register_language(
    #     :toml,
    #     grammar_module: TomlRB::Document,
    #     gem_name: "toml-rb"
    #   )
    # @example Register BOTH backends in ONE call (recommended for maximum flexibility)
    #   TreeHaver.register_language(
    #     :toml,
    #     path: "/usr/local/lib/libtree-sitter-toml.so",
    #     symbol: "tree_sitter_toml",
    #     grammar_module: TomlRB::Document,
    #     gem_name: "toml-rb"
    #   )
    #   # Now TreeHaver::Language.toml works with ANY backend!
    def register_language(name, path: nil, symbol: nil, grammar_module: nil, gem_name: nil)
      # Register tree-sitter backend if path provided
      # Note: Uses `if` not `elsif` so both backends can be registered in one call
      if path
        LanguageRegistry.register(name, :tree_sitter, path: path, symbol: symbol)
      end

      # Register Citrus backend if grammar_module provided
      # Note: Uses `if` not `elsif` so both backends can be registered in one call
      # This allows maximum flexibility - register once, use with any backend
      if grammar_module
        unless grammar_module.respond_to?(:parse)
          raise ArgumentError, "Grammar module must respond to :parse"
        end

        LanguageRegistry.register(name, :citrus, grammar_module: grammar_module, gem_name: gem_name)
      end

      # Require at least one backend to be registered
      if path.nil? && grammar_module.nil?
        raise ArgumentError, "Must provide at least one of: path (tree-sitter) or grammar_module (Citrus)"
      end

      # Note: No early return! This method intentionally processes both `if` blocks
      # above to allow registering multiple backends for the same language.
      # Both tree-sitter and Citrus can be registered simultaneously for maximum
      # flexibility. See method documentation for rationale.
      nil
    end

    # Fetch a registered language entry
    #
    # @api private
    # @param name [Symbol, String] language identifier
    # @return [Hash, nil] registration hash with keys :path and :symbol, or nil if not registered
    def registered_language(name)
      LanguageRegistry.registered(name)
    end

    # Create a parser configured for a specific language
    #
    # This is the recommended high-level API for creating a parser. It handles:
    # 1. Checking if the language is already registered
    # 2. Auto-discovering tree-sitter grammar via GrammarFinder
    # 3. Falling back to Citrus grammar if tree-sitter is unavailable
    # 4. Creating and configuring the parser
    #
    # @param language_name [Symbol, String] the language to parse (e.g., :toml, :json, :bash)
    # @param library_path [String, nil] optional explicit path to tree-sitter grammar library
    # @param symbol [String, nil] optional tree-sitter symbol name (defaults to "tree_sitter_<name>")
    # @param citrus_config [Hash, nil] optional Citrus fallback configuration
    # @option citrus_config [String] :gem_name gem name for the Citrus grammar
    # @option citrus_config [String] :grammar_const fully qualified constant name for grammar module
    # @return [TreeHaver::Parser] configured parser with language set
    # @raise [TreeHaver::NotAvailable] if no parser backend is available for the language
    #
    # @example Basic usage (auto-discovers grammar)
    #   parser = TreeHaver.parser_for(:toml)
    #   tree = parser.parse("[package]\nname = \"my-app\"")
    #
    # @example With explicit library path
    #   parser = TreeHaver.parser_for(:toml, library_path: "/custom/path/libtree-sitter-toml.so")
    #
    # @example With Citrus fallback configuration
    #   parser = TreeHaver.parser_for(:toml,
    #     citrus_config: { gem_name: "toml-rb", grammar_const: "TomlRB::Document" }
    #   )
    def parser_for(language_name, library_path: nil, symbol: nil, citrus_config: nil)
      name = language_name.to_sym
      symbol ||= "tree_sitter_#{name}"

      # Step 1: Try to get the language (may already be registered)
      language = begin
        # Check if already registered and loadable
        if registered_language(name)
          Language.public_send(name, path: library_path, symbol: symbol)
        end
      rescue NotAvailable, ArgumentError, LoadError
        nil
      end

      # Step 2: If not registered, try GrammarFinder for tree-sitter
      unless language
        # Principle of Least Surprise: If user provides an explicit path,
        # it MUST exist. Don't silently fall back to auto-discovery.
        if library_path && !library_path.empty?
          unless File.exist?(library_path)
            raise NotAvailable,
              "Specified parser path does not exist: #{library_path}"
          end
          begin
            register_language(name, path: library_path, symbol: symbol)
            language = Language.public_send(name)
          rescue NotAvailable, ArgumentError, LoadError => e
            # Re-raise with more context since user explicitly provided this path
            raise NotAvailable,
              "Failed to load parser from specified path #{library_path}: #{e.message}"
          end
        else
          # Auto-discover via GrammarFinder (no explicit path provided)
          begin
            finder = GrammarFinder.new(name)
            if finder.available?
              finder.register!
              language = Language.public_send(name)
            end
          rescue NotAvailable, ArgumentError, LoadError
            language = nil
          end
        end
      end

      # Step 3: Try Citrus fallback if tree-sitter failed
      unless language
        # Use explicit config, or fall back to built-in defaults for known languages
        citrus_config ||= CITRUS_DEFAULTS[name] || {}

        # Only attempt if we have the required configuration
        if citrus_config[:gem_name] && citrus_config[:grammar_const]
          begin
            citrus_finder = CitrusGrammarFinder.new(
              language: name,
              gem_name: citrus_config[:gem_name],
              grammar_const: citrus_config[:grammar_const],
              require_path: citrus_config[:require_path],
            )
            if citrus_finder.available?
              citrus_finder.register!
              language = Language.public_send(name)
            end
          rescue NotAvailable, ArgumentError, LoadError, NameError, TypeError
            language = nil
          end
        end
      end

      # Step 4: Raise if nothing worked
      unless language
        raise NotAvailable,
          "No parser available for #{name}. " \
            "Install tree-sitter-#{name} or the appropriate Ruby gem. " \
            "Set TREE_SITTER_#{name.to_s.upcase}_PATH for custom grammar location."
      end

      # Step 5: Create and configure parser
      parser = Parser.new
      parser.language = language
      parser
    end
  end

  # Language and Parser classes have been moved to separate files:
  # - tree_haver/language.rb: TreeHaver::Language - loads grammar shared libraries
  # - tree_haver/parser.rb: TreeHaver::Parser - parses source code into syntax trees
  # - tree_haver/tree.rb: TreeHaver::Tree - unified wrapper providing consistent API
  # - tree_haver/node.rb: TreeHaver::Node - unified wrapper providing consistent API
  #
  # These provide a unified interface across all backends (MRI, Rust, FFI, Java, Citrus).
  # All backends now return properly wrapped TreeHaver::Tree and TreeHaver::Node objects.
end # end module TreeHaver

TreeHaver::Version.class_eval do
  extend VersionGem::Basic
end
