# frozen_string_literal: true

# External gems
require "version_gem"

# Standard library
require "set"

# This gem
require_relative "tree_haver/version"
require_relative "tree_haver/language_registry"

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

  # Represents a tree-sitter language grammar
  #
  # A Language object is an opaque handle to a TSLanguage* that defines
  # the grammar rules for parsing a specific programming language.
  #
  # @example Load a language from a shared library
  #   language = TreeHaver::Language.from_library(
  #     "/usr/local/lib/libtree-sitter-toml.so",
  #     symbol: "tree_sitter_toml"
  #   )
  #
  # @example Use a registered language
  #   TreeHaver.register_language(:toml, path: "/path/to/libtree-sitter-toml.so")
  #   language = TreeHaver::Language.toml
  class Language
    class << self
      # Load a language grammar from a shared library (ruby_tree_sitter compatibility)
      #
      # This method provides API compatibility with ruby_tree_sitter which uses
      # `Language.load(name, path)`.
      #
      # @param name [String] the language name (e.g., "toml")
      # @param path [String] absolute path to the language shared library
      # @param validate [Boolean] if true, validates the path for safety (default: true)
      # @return [Language] loaded language handle
      # @raise [NotAvailable] if the library cannot be loaded
      # @raise [ArgumentError] if the path fails security validation
      # @example
      #   language = TreeHaver::Language.load("toml", "/usr/local/lib/libtree-sitter-toml.so")
      def load(name, path, validate: true)
        from_library(path, symbol: "tree_sitter_#{name}", name: name, validate: validate)
      end

      # Load a language grammar from a shared library
      #
      # The library must export a function that returns a pointer to a TSLanguage struct.
      # By default, TreeHaver looks for a symbol named "tree_sitter_<name>".
      #
      # == Security
      #
      # By default, paths are validated using {PathValidator} to prevent path traversal
      # and other attacks. Set `validate: false` to skip validation (not recommended
      # unless you've already validated the path).
      #
      # @param path [String] absolute path to the language shared library (.so/.dylib/.dll)
      # @param symbol [String, nil] name of the exported function (defaults to auto-detection)
      # @param name [String, nil] logical name for the language (used in caching)
      # @param validate [Boolean] if true, validates path and symbol for safety (default: true)
      # @param backend [Symbol, String, nil] optional backend to use (overrides context/global)
      # @return [Language] loaded language handle
      # @raise [NotAvailable] if the library cannot be loaded or the symbol is not found
      # @raise [ArgumentError] if path or symbol fails security validation
      # @example
      #   language = TreeHaver::Language.from_library(
      #     "/usr/local/lib/libtree-sitter-toml.so",
      #     symbol: "tree_sitter_toml",
      #     name: "toml"
      #   )
      # @example With explicit backend
      #   language = TreeHaver::Language.from_library(
      #     "/usr/local/lib/libtree-sitter-toml.so",
      #     symbol: "tree_sitter_toml",
      #     backend: :ffi
      #   )
      def from_library(path, symbol: nil, name: nil, validate: true, backend: nil)
        if validate
          unless PathValidator.safe_library_path?(path)
            errors = PathValidator.validation_errors(path)
            raise ArgumentError, "Unsafe library path: #{path.inspect}. Errors: #{errors.join("; ")}"
          end

          if symbol && !PathValidator.safe_symbol_name?(symbol)
            raise ArgumentError, "Unsafe symbol name: #{symbol.inspect}. " \
              "Symbol names must be valid C identifiers."
          end
        end

        # from_library only works with tree-sitter backends that support .so files
        # Pure Ruby backends (Citrus, Prism, Psych, Commonmarker, Markly) don't support from_library
        mod = TreeHaver.resolve_native_backend_module(backend)

        if mod.nil?
          if backend
            raise NotAvailable, "Requested backend #{backend.inspect} is not available or does not support shared libraries"
          else
            raise NotAvailable,
              "No native tree-sitter backend is available for loading shared libraries. " \
                "Available native backends (MRI, Rust, FFI, Java) require platform-specific setup. " \
                "For pure-Ruby parsing, use backend-specific Language classes directly (e.g., Prism, Psych, Citrus)."
          end
        end

        # Backend must implement .from_library; fallback to .from_path for older impls
        # Include effective backend AND ENV vars in cache key since they affect loading
        effective_b = TreeHaver.resolve_effective_backend(backend)
        key = [effective_b, path, symbol, name, ENV["TREE_SITTER_LANG_SYMBOL"]]
        LanguageRegistry.fetch(key) do
          if mod::Language.respond_to?(:from_library)
            mod::Language.from_library(path, symbol: symbol, name: name)
          else
            mod::Language.from_path(path)
          end
        end
      end
      # Alias for {from_library}
      # @see from_library
      alias_method :from_path, :from_library

      # Dynamic helper to load a registered language by name
      #
      # After registering a language with {TreeHaver.register_language},
      # you can load it using a method call. The appropriate backend will be
      # used based on registration and current backend.
      #
      # @example With tree-sitter
      #   TreeHaver.register_language(:toml, path: "/path/to/libtree-sitter-toml.so")
      #   language = TreeHaver::Language.toml
      #
      # @example With both backends
      #   TreeHaver.register_language(:toml,
      #     path: "/path/to/libtree-sitter-toml.so", symbol: "tree_sitter_toml")
      #   TreeHaver.register_language(:toml,
      #     grammar_module: TomlRB::Document)
      #   language = TreeHaver::Language.toml  # Uses appropriate grammar for active backend
      #
      # @param method_name [Symbol] the registered language name
      # @param args [Array] positional arguments
      # @param kwargs [Hash] keyword arguments
      # @return [Language] loaded language handle
      # @raise [NoMethodError] if the language name is not registered
      def method_missing(method_name, *args, **kwargs, &block)
        # Resolve only if the language name was registered
        all_backends = TreeHaver.registered_language(method_name)
        return super unless all_backends

        # Check current backend
        current_backend = TreeHaver.backend_module

        # Determine which backend type to use
        backend_type = if current_backend == Backends::Citrus
          :citrus
        else
          :tree_sitter  # MRI, Rust, FFI, Java all use tree-sitter
        end

        # Get backend-specific registration
        reg = all_backends[backend_type]

        # If Citrus backend is active
        if backend_type == :citrus
          if reg && reg[:grammar_module]
            return Backends::Citrus::Language.new(reg[:grammar_module])
          end

          # Fall back to error if no Citrus grammar registered
          raise NotAvailable,
            "Citrus backend is active but no Citrus grammar registered for :#{method_name}. " \
              "Either register a Citrus grammar or use a tree-sitter backend. " \
              "Registered backends: #{all_backends.keys.inspect}"
        end

        # For tree-sitter backends, try to load from path
        # If that fails, fall back to Citrus if available
        if reg && reg[:path]
          path = kwargs[:path] || args.first || reg[:path]
          # Symbol priority: kwargs override > registration > derive from method_name
          symbol = if kwargs.key?(:symbol)
            kwargs[:symbol]
          elsif reg[:symbol]
            reg[:symbol]
          else
            "tree_sitter_#{method_name}"
          end
          # Name priority: kwargs override > derive from symbol (strip tree_sitter_ prefix)
          # Using symbol-derived name ensures ruby_tree_sitter gets the correct language name
          # e.g., "toml" not "toml_both" when symbol is "tree_sitter_toml"
          name = kwargs[:name] || symbol&.sub(/\Atree_sitter_/, "")

          begin
            return from_library(path, symbol: symbol, name: name)
          rescue NotAvailable, ArgumentError, LoadError, FFI::NotFoundError => _e
            # Tree-sitter failed to load - check for Citrus fallback
            # This handles cases where:
            # - The .so file doesn't exist or can't be loaded (NotAvailable, LoadError)
            # - FFI can't find required symbols like ts_parser_new (FFI::NotFoundError)
            # - Invalid arguments were provided (ArgumentError)
            citrus_reg = all_backends[:citrus]
            if citrus_reg && citrus_reg[:grammar_module]
              return Backends::Citrus::Language.new(citrus_reg[:grammar_module])
            end
            # No Citrus fallback available, re-raise the original error
            raise
          end
        end

        # No tree-sitter path registered - check for Citrus fallback
        # This enables auto-fallback when tree-sitter grammar is not installed
        # but a Citrus grammar (pure Ruby) is available
        citrus_reg = all_backends[:citrus]
        if citrus_reg && citrus_reg[:grammar_module]
          return Backends::Citrus::Language.new(citrus_reg[:grammar_module])
        end

        # No appropriate registration found
        raise ArgumentError,
          "No grammar registered for :#{method_name} compatible with #{backend_type} backend. " \
            "Registered backends: #{all_backends.keys.inspect}"
      end

      # @api private
      def respond_to_missing?(method_name, include_private = false)
        !!TreeHaver.registered_language(method_name) || super
      end
    end
  end

  # Represents a tree-sitter parser instance
  #
  # A Parser is used to parse source code into a syntax tree. You must
  # set a language before parsing.
  #
  # == Wrapping/Unwrapping Responsibility
  #
  # TreeHaver::Parser is responsible for ALL object wrapping and unwrapping:
  #
  # **Language objects:**
  # - Unwraps Language wrappers before passing to backend.language=
  # - MRI backend receives ::TreeSitter::Language
  # - Rust backend receives String (language name)
  # - FFI backend receives wrapped Language (needs to_ptr)
  #
  # **Tree objects:**
  # - parse() receives raw source, backend returns raw tree, Parser wraps it
  # - parse_string() unwraps old_tree before passing to backend, wraps returned tree
  # - Backends always work with raw backend trees, never TreeHaver::Tree
  #
  # **Node objects:**
  # - Backends return raw nodes, TreeHaver::Tree and TreeHaver::Node wrap them
  #
  # This design ensures:
  # - Principle of Least Surprise: wrapping happens at boundaries, consistently
  # - Backends are simple: they don't need to know about TreeHaver wrappers
  # - Single Responsibility: wrapping logic is only in TreeHaver::Parser
  #
  # @example Basic parsing
  #   parser = TreeHaver::Parser.new
  #   parser.language = TreeHaver::Language.toml
  #   tree = parser.parse("[package]\nname = \"foo\"")
  class Parser
    # Create a new parser instance
    #
    # @param backend [Symbol, String, nil] optional backend to use (overrides context/global)
    # @raise [NotAvailable] if no backend is available or requested backend is unavailable
    # @example Default (uses context/global)
    #   parser = TreeHaver::Parser.new
    # @example Explicit backend
    #   parser = TreeHaver::Parser.new(backend: :ffi)
    def initialize(backend: nil)
      # Convert string backend names to symbols for consistency
      backend = backend.to_sym if backend.is_a?(String)

      mod = TreeHaver.resolve_backend_module(backend)

      if mod.nil?
        if backend
          raise NotAvailable, "Requested backend #{backend.inspect} is not available"
        else
          raise NotAvailable, "No TreeHaver backend is available"
        end
      end

      # Try to create the parser, with fallback to Citrus if tree-sitter fails
      # This enables auto-fallback when tree-sitter runtime isn't available
      begin
        @impl = mod::Parser.new
        @explicit_backend = backend  # Remember for introspection (always a Symbol or nil)
      rescue NoMethodError, FFI::NotFoundError, LoadError => e
        # Tree-sitter backend failed (likely missing runtime library)
        # Try Citrus as fallback if we weren't explicitly asked for a specific backend
        if backend.nil? || backend == :auto
          if Backends::Citrus.available?
            @impl = Backends::Citrus::Parser.new
            @explicit_backend = :citrus
          else
            # No fallback available, re-raise original error
            raise NotAvailable, "Tree-sitter backend failed: #{e.message}. " \
              "Citrus fallback not available. Install tree-sitter runtime or citrus gem."
          end
        else
          # Explicit backend was requested, don't fallback
          raise
        end
      end
    end

    # Get the backend this parser is using (for introspection)
    #
    # Returns the actual backend in use, resolving :auto to the concrete backend.
    #
    # @return [Symbol] the backend name (:mri, :rust, :ffi, :java, or :citrus)
    def backend
      if @explicit_backend && @explicit_backend != :auto
        @explicit_backend
      else
        # Determine actual backend from the implementation class
        case @impl.class.name
        when /MRI/
          :mri
        when /Rust/
          :rust
        when /FFI/
          :ffi
        when /Java/
          :java
        when /Citrus/
          :citrus
        else
          # Fallback to effective_backend if we can't determine from class name
          TreeHaver.effective_backend
        end
      end
    end

    # Set the language grammar for this parser
    #
    # @param lang [Language] the language to use for parsing
    # @return [Language] the language that was set
    # @example
    #   parser.language = TreeHaver::Language.from_library("/path/to/grammar.so")
    def language=(lang)
      # Check if this is a Citrus language - if so, we need a Citrus parser
      # This enables automatic backend switching when tree-sitter fails and
      # falls back to Citrus
      if lang.is_a?(Backends::Citrus::Language)
        unless @impl.is_a?(Backends::Citrus::Parser)
          # Switch to Citrus parser to match the Citrus language
          @impl = Backends::Citrus::Parser.new
          @explicit_backend = :citrus
        end
      end

      # Unwrap the language before passing to backend
      # Backends receive raw language objects, never TreeHaver wrappers
      inner_lang = unwrap_language(lang)
      @impl.language = inner_lang
      # Return the original (possibly wrapped) language for consistency
      lang # rubocop:disable Lint/Void (intentional return value)
    end

    private

    # Unwrap a language object to extract the raw backend language
    #
    # This method is smart about backend compatibility:
    # 1. If language has a backend attribute, checks if it matches current backend
    # 2. If mismatch detected, attempts to reload language for correct backend
    # 3. If reload successful, uses new language; otherwise continues with original
    # 4. Unwraps the language wrapper to get raw backend object
    #
    # @param lang [Object] wrapped or raw language object
    # @return [Object] raw backend language object appropriate for current backend
    # @api private
    def unwrap_language(lang)
      # Check if this is a TreeHaver language wrapper with backend info
      if lang.respond_to?(:backend)
        # Verify backend compatibility FIRST
        # This prevents passing languages from wrong backends to native code
        # Exception: :auto backend is permissive - accepts any language
        current_backend = backend

        if lang.backend != current_backend && current_backend != :auto
          # Backend mismatch! Try to reload for correct backend
          reloaded = try_reload_language_for_backend(lang, current_backend)
          if reloaded
            lang = reloaded
          else
            # Couldn't reload - this is an error
            raise TreeHaver::Error,
              "Language backend mismatch: language is for #{lang.backend}, parser is #{current_backend}. " \
                "Cannot reload language for correct backend. " \
                "Create a new language with TreeHaver::Language.from_library when backend is #{current_backend}."
          end
        end

        # Get the current parser's language (if set)
        current_lang = @impl.respond_to?(:language) ? @impl.language : nil

        # Language mismatch detected! The parser might have a different language set
        # Compare the actual language objects using Comparable
        if current_lang && lang != current_lang
          # Different language being set (e.g., switching from TOML to JSON)
          # This is fine, just informational
        end
      end

      # Unwrap based on backend type
      # All TreeHaver Language wrappers have the backend attribute
      unless lang.respond_to?(:backend)
        # This shouldn't happen - all our wrappers have backend attribute
        # If we get here, it's likely a raw backend object that was passed directly
        raise TreeHaver::Error,
          "Expected TreeHaver Language wrapper with backend attribute, got #{lang.class}. " \
            "Use TreeHaver::Language.from_library to create language objects."
      end

      case lang.backend
      when :mri
        return lang.to_language if lang.respond_to?(:to_language)
        return lang.inner_language if lang.respond_to?(:inner_language)
      when :rust
        return lang.name if lang.respond_to?(:name)
      when :ffi
        return lang  # FFI needs wrapper for to_ptr
      when :java
        return lang.impl if lang.respond_to?(:impl)
      when :citrus
        return lang.grammar_module if lang.respond_to?(:grammar_module)
      when :prism
        return lang  # Prism backend expects the Language wrapper
      when :psych
        return lang  # Psych backend expects the Language wrapper
      when :commonmarker
        return lang  # Commonmarker backend expects the Language wrapper
      when :markly
        return lang  # Markly backend expects the Language wrapper
      else
        # Unknown backend (e.g., test backend)
        # Try generic unwrapping methods for flexibility in testing
        return lang.to_language if lang.respond_to?(:to_language)
        return lang.inner_language if lang.respond_to?(:inner_language)
        return lang.impl if lang.respond_to?(:impl)
        return lang.grammar_module if lang.respond_to?(:grammar_module)
        return lang.name if lang.respond_to?(:name)

        # If nothing works, pass through as-is
        # This allows test languages to be passed directly
        return lang
      end

      # Shouldn't reach here, but just in case
      lang
    end

    # Try to reload a language for the current backend
    #
    # This handles the case where a language was loaded for one backend,
    # but is now being used with a different backend (e.g., after backend switch).
    #
    # @param lang [Object] language object with metadata
    # @param target_backend [Symbol] backend to reload for
    # @return [Object, nil] reloaded language or nil if reload not possible
    # @api private
    def try_reload_language_for_backend(lang, target_backend)
      # Can't reload without path information
      return unless lang.respond_to?(:path) || lang.respond_to?(:grammar_module)

      # For tree-sitter backends, reload from path
      if lang.respond_to?(:path) && lang.path
        begin
          # Use Language.from_library which respects current backend
          return Language.from_library(
            lang.path,
            symbol: lang.respond_to?(:symbol) ? lang.symbol : nil,
            name: lang.respond_to?(:name) ? lang.name : nil,
          )
        rescue => e
          # Reload failed, continue with original
          warn("TreeHaver: Failed to reload language for backend #{target_backend}: #{e.message}") if $VERBOSE
          return
        end
      end

      # For Citrus, can't really reload as it's just a module reference
      nil
    end

    public

    # Parse source code into a syntax tree
    #
    # @param source [String] the source code to parse (should be UTF-8)
    # @return [Tree] the parsed syntax tree
    # @example
    #   tree = parser.parse("x = 1")
    #   puts tree.root_node.type
    def parse(source)
      tree_impl = @impl.parse(source)
      # Wrap backend tree with source so Node#text works
      Tree.new(tree_impl, source: source)
    end

    # Parse source code into a syntax tree (with optional incremental parsing)
    #
    # This method provides API compatibility with ruby_tree_sitter which uses
    # `parse_string(old_tree, source)`.
    #
    # == Incremental Parsing
    #
    # tree-sitter supports **incremental parsing** where you can pass a previously
    # parsed tree along with edit information to efficiently re-parse only the
    # changed portions of source code. This is a major performance optimization
    # for editors and IDEs that need to re-parse on every keystroke.
    #
    # The workflow for incremental parsing is:
    # 1. Parse the initial source: `tree = parser.parse_string(nil, source)`
    # 2. User edits the source (e.g., inserts a character)
    # 3. Call `tree.edit(...)` to update the tree's position data
    # 4. Re-parse with the old tree: `new_tree = parser.parse_string(tree, new_source)`
    # 5. tree-sitter reuses unchanged nodes, only re-parsing affected regions
    #
    # TreeHaver passes through to the underlying backend if it supports incremental
    # parsing (MRI and Rust backends do). Check `TreeHaver.capabilities[:incremental]`
    # to see if the current backend supports it.
    #
    # @param old_tree [Tree, nil] previously parsed tree for incremental parsing, or nil for fresh parse
    # @param source [String] the source code to parse (should be UTF-8)
    # @return [Tree] the parsed syntax tree
    # @see https://tree-sitter.github.io/tree-sitter/using-parsers#editing tree-sitter incremental parsing docs
    # @see Tree#edit For marking edits before incremental re-parsing
    # @example First parse (no old tree)
    #   tree = parser.parse_string(nil, "x = 1")
    # @example Incremental parse
    #   tree.edit(start_byte: 4, old_end_byte: 5, new_end_byte: 6, ...)
    #   new_tree = parser.parse_string(tree, "x = 42")
    def parse_string(old_tree, source)
      # Pass through to backend if it supports incremental parsing
      if old_tree && @impl.respond_to?(:parse_string)
        # Extract the underlying implementation from our Tree wrapper
        old_impl = if old_tree.respond_to?(:inner_tree)
          old_tree.inner_tree
        elsif old_tree.respond_to?(:instance_variable_get)
          # Fallback for compatibility
          old_tree.instance_variable_get(:@inner_tree) || old_tree.instance_variable_get(:@impl) || old_tree
        else
          old_tree
        end
        tree_impl = @impl.parse_string(old_impl, source)
        # Wrap backend tree with source so Node#text works
        Tree.new(tree_impl, source: source)
      elsif @impl.respond_to?(:parse_string)
        tree_impl = @impl.parse_string(nil, source)
        # Wrap backend tree with source so Node#text works
        Tree.new(tree_impl, source: source)
      else
        # Fallback for backends that don't support parse_string
        parse(source)
      end
    end
  end

  # Tree and Node classes have been moved to separate files:
  # - tree_haver/tree.rb: TreeHaver::Tree - unified wrapper providing consistent API
  # - tree_haver/node.rb: TreeHaver::Node - unified wrapper providing consistent API
  #
  # These provide a unified interface across all backends (MRI, Rust, FFI, Java, Citrus).
  # All backends now return properly wrapped TreeHaver::Tree and TreeHaver::Node objects.
end # end module TreeHaver

TreeHaver::Version.class_eval do
  extend VersionGem::Basic
end
