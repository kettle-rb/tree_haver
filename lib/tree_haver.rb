# frozen_string_literal: true

# External gems
require "version_gem"

# This gem
require_relative "tree_haver/version"
require_relative "tree_haver/language_registry"

# TreeHaver is a cross-Ruby adapter for the Tree-sitter parsing library.
#
# It provides a unified API for parsing source code using Tree-sitter grammars,
# working seamlessly across MRI Ruby, JRuby, and TruffleRuby.
#
# @example Basic usage with TOML
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
#   # Traverse the AST
#   root.each { |child| puts child.type }
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
# @example Using GrammarFinder in a *-merge gem
#   # Each merge gem (toml-merge, json-merge, bash-merge) uses the same pattern
#   finder = TreeHaver::GrammarFinder.new(:toml)  # or :json, :bash, etc.
#   if finder.available?
#     finder.register!
#   else
#     warn finder.not_found_message
#   end
#
# @example Selecting a backend
#   TreeHaver.backend = :ffi  # Force FFI backend
#   TreeHaver.backend = :mri  # Force MRI backend
#   TreeHaver.backend = :auto # Auto-select (default)
#
# @see https://tree-sitter.github.io/tree-sitter/ Tree-sitter documentation
# @see GrammarFinder For automatic grammar library discovery
module TreeHaver
  # Base error class for TreeHaver exceptions
  #
  # @abstract Subclass to create specific error types
  class Error < StandardError; end

  # Raised when a requested backend or feature is not available
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

  # Namespace for backend implementations
  #
  # TreeHaver provides multiple backends to support different Ruby implementations:
  # - {Backends::MRI} - Uses ruby_tree_sitter (MRI C extension)
  # - {Backends::Rust} - Uses tree_stump (Rust extension with precompiled binaries)
  # - {Backends::FFI} - Uses Ruby FFI to call libtree-sitter directly
  # - {Backends::Java} - Uses JRuby's Java integration (planned)
  module Backends
    autoload :MRI, File.join(__dir__, "tree_haver", "backends", "mri")
    autoload :Rust, File.join(__dir__, "tree_haver", "backends", "rust")
    autoload :FFI, File.join(__dir__, "tree_haver", "backends", "ffi")
    autoload :Java, File.join(__dir__, "tree_haver", "backends", "java")
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

  # Get the current backend selection
  #
  # @return [Symbol] one of :auto, :mri, :ffi, or :java
  # @note Can be set via ENV["TREE_HAVER_BACKEND"]
  class << self
    # @example
    #   TreeHaver.backend  # => :auto
    def backend
      @backend ||= case (ENV["TREE_HAVER_BACKEND"] || :auto).to_s # rubocop:disable ThreadSafety/ClassInstanceVariable
      when "mri" then :mri
      when "rust" then :rust
      when "ffi" then :ffi
      when "java" then :java
      else :auto
      end
    end

    # Set the backend to use
    #
    # @param name [Symbol, String, nil] backend name (:auto, :mri, :rust, :ffi, :java)
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

    # Determine the concrete backend module to use
    #
    # This method performs backend auto-selection when backend is :auto.
    # On JRuby, prefers Java backend if available, then FFI.
    # On MRI, prefers MRI backend if available, then Rust, then FFI.
    #
    # @return [Module, nil] the backend module (Backends::MRI, Backends::Rust, Backends::FFI, or Backends::Java), or nil if none available
    # @example
    #   mod = TreeHaver.backend_module
    #   if mod
    #     puts "Using #{mod.capabilities[:backend]} backend"
    #   end
    def backend_module
      case backend
      when :mri
        Backends::MRI
      when :rust
        Backends::Rust
      when :ffi
        Backends::FFI
      when :java
        Backends::Java
      else
        # auto-select: on JRuby prefer Java backend if available; on MRI prefer MRI, then Rust; otherwise FFI
        if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby" && Backends::Java.available?
          Backends::Java
        elsif defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby" && Backends::MRI.available?
          Backends::MRI
        elsif defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby" && Backends::Rust.available?
          Backends::Rust
        elsif Backends::FFI.available?
          Backends::FFI
        else
          # No backend available yet
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

    # Register a language helper by name
    #
    # After registration, you can use dynamic helpers like `TreeHaver::Language.toml`
    # to load the registered language.
    #
    # @param name [Symbol, String] language identifier (e.g., :toml, :json)
    # @param path [String] absolute path to the language shared library
    # @param symbol [String, nil] optional exported factory symbol (e.g., "tree_sitter_toml")
    # @return [void]
    # @example Register TOML grammar
    #   TreeHaver.register_language(
    #     :toml,
    #     path: "/usr/local/lib/libtree-sitter-toml.so",
    #     symbol: "tree_sitter_toml"
    #   )
    def register_language(name, path:, symbol: nil)
      LanguageRegistry.register(name, path: path, symbol: symbol)
    end

    # Unregister a previously registered language helper
    #
    # @param name [Symbol, String] language identifier to unregister
    # @return [void]
    # @example
    #   TreeHaver.unregister_language(:toml)
    def unregister_language(name)
      LanguageRegistry.unregister(name)
    end

    # Clear all registered languages
    #
    # Primarily intended for test cleanup and resetting state.
    #
    # @return [void]
    # @example
    #   TreeHaver.clear_languages!
    def clear_languages!
      LanguageRegistry.clear_registrations!
    end

    # Fetch a registered language entry
    #
    # @api private
    # @param name [Symbol, String] language identifier
    # @return [Hash, nil] registration hash with keys :path and :symbol, or nil if not registered
    def registered_language(name)
      LanguageRegistry.registered(name)
    end
  end

  # Represents a Tree-sitter language grammar
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
      # @return [Language] loaded language handle
      # @raise [NotAvailable] if the library cannot be loaded or the symbol is not found
      # @raise [ArgumentError] if path or symbol fails security validation
      # @example
      #   language = TreeHaver::Language.from_library(
      #     "/usr/local/lib/libtree-sitter-toml.so",
      #     symbol: "tree_sitter_toml",
      #     name: "toml"
      #   )
      def from_library(path, symbol: nil, name: nil, validate: true)
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

        mod = TreeHaver.backend_module
        raise NotAvailable, "No TreeHaver backend is available" unless mod
        # Backend must implement .from_library; fallback to .from_path for older impls
        # Include ENV vars in cache key since they affect symbol resolution
        key = [path, symbol, name, ENV["TREE_SITTER_LANG_SYMBOL"]]
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
      # you can load it using a method call:
      #
      # @example
      #   TreeHaver.register_language(:toml, path: "/path/to/libtree-sitter-toml.so")
      #   language = TreeHaver::Language.toml
      #
      # @example With overrides
      #   language = TreeHaver::Language.toml(path: "/custom/path.so")
      #
      # @param method_name [Symbol] the registered language name
      # @param args [Array] positional arguments (first is used as path if provided)
      # @param kwargs [Hash] keyword arguments (:path, :symbol, :name)
      # @return [Language] loaded language handle
      # @raise [NoMethodError] if the language name is not registered
      def method_missing(method_name, *args, **kwargs, &block)
        # Resolve only if the language name was registered
        reg = TreeHaver.registered_language(method_name)
        return super unless reg

        # Allow per-call overrides; otherwise use registered defaults
        path = kwargs[:path] || args.first || reg[:path]
        raise ArgumentError, "path is required" unless path
        symbol = kwargs.key?(:symbol) ? kwargs[:symbol] : (reg[:symbol] || "tree_sitter_#{method_name}")
        name = kwargs[:name] || method_name.to_s
        from_library(path, symbol: symbol, name: name)
      end

      # @api private
      def respond_to_missing?(method_name, include_private = false)
        !!TreeHaver.registered_language(method_name) || super
      end
    end
  end

  # Represents a Tree-sitter parser instance
  #
  # A Parser is used to parse source code into a syntax tree. You must
  # set a language before parsing.
  #
  # @example Basic parsing
  #   parser = TreeHaver::Parser.new
  #   parser.language = TreeHaver::Language.toml
  #   tree = parser.parse("[package]\nname = \"foo\"")
  class Parser
    # Create a new parser instance
    #
    # @raise [NotAvailable] if no backend is available
    def initialize
      mod = TreeHaver.backend_module
      raise NotAvailable, "No TreeHaver backend is available" unless mod
      @impl = mod::Parser.new
    end

    # Set the language grammar for this parser
    #
    # @param lang [Language] the language to use for parsing
    # @return [Language] the language that was set
    # @example
    #   parser.language = TreeHaver::Language.from_library("/path/to/grammar.so")
    def language=(lang)
      @impl.language = lang
    end

    # Parse source code into a syntax tree
    #
    # @param source [String] the source code to parse (should be UTF-8)
    # @return [Tree] the parsed syntax tree
    # @example
    #   tree = parser.parse("x = 1")
    #   puts tree.root_node.type
    def parse(source)
      tree_impl = @impl.parse(source)
      Tree.new(tree_impl)
    end

    # Parse source code into a syntax tree (with optional incremental parsing)
    #
    # This method provides API compatibility with ruby_tree_sitter which uses
    # `parse_string(old_tree, source)`.
    #
    # == Incremental Parsing
    #
    # Tree-sitter supports **incremental parsing** where you can pass a previously
    # parsed tree along with edit information to efficiently re-parse only the
    # changed portions of source code. This is a major performance optimization
    # for editors and IDEs that need to re-parse on every keystroke.
    #
    # The workflow for incremental parsing is:
    # 1. Parse the initial source: `tree = parser.parse_string(nil, source)`
    # 2. User edits the source (e.g., inserts a character)
    # 3. Call `tree.edit(...)` to update the tree's position data
    # 4. Re-parse with the old tree: `new_tree = parser.parse_string(tree, new_source)`
    # 5. Tree-sitter reuses unchanged nodes, only re-parsing affected regions
    #
    # TreeHaver passes through to the underlying backend if it supports incremental
    # parsing (MRI and Rust backends do). Check `TreeHaver.capabilities[:incremental]`
    # to see if the current backend supports it.
    #
    # @param old_tree [Tree, nil] previously parsed tree for incremental parsing, or nil for fresh parse
    # @param source [String] the source code to parse (should be UTF-8)
    # @return [Tree] the parsed syntax tree
    # @see https://tree-sitter.github.io/tree-sitter/using-parsers#editing Tree-sitter incremental parsing docs
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
        old_impl = old_tree.is_a?(Tree) ? old_tree.instance_variable_get(:@impl) : old_tree
        tree_impl = @impl.parse_string(old_impl, source)
        Tree.new(tree_impl)
      elsif @impl.respond_to?(:parse_string)
        tree_impl = @impl.parse_string(nil, source)
        Tree.new(tree_impl)
      else
        # Fallback for backends that don't support parse_string
        parse(source)
      end
    end
  end

  # Represents a parsed syntax tree
  #
  # A Tree is the result of parsing source code. It provides access to
  # the root node of the AST and supports incremental parsing via the
  # {#edit} method.
  #
  # @example Basic usage
  #   tree = parser.parse(source)
  #   root = tree.root_node
  #
  # @example Incremental parsing
  #   tree = parser.parse_string(nil, original_source)
  #   tree.edit(
  #     start_byte: 10,
  #     old_end_byte: 15,
  #     new_end_byte: 20,
  #     start_point: { row: 0, column: 10 },
  #     old_end_point: { row: 0, column: 15 },
  #     new_end_point: { row: 0, column: 20 }
  #   )
  #   new_tree = parser.parse_string(tree, edited_source)
  class Tree
    # @api private
    def initialize(impl)
      @impl = impl
    end

    # Get the root node of the syntax tree
    #
    # @return [Node] the root node
    # @example
    #   root = tree.root_node
    #   puts root.type  # => "document" or similar
    def root_node
      Node.new(@impl.root_node)
    end

    # Mark the tree as edited for incremental re-parsing
    #
    # Call this method after the source code has been modified but before
    # re-parsing. This tells Tree-sitter which parts of the tree are
    # invalidated so it can efficiently re-parse only the affected regions.
    #
    # @param start_byte [Integer] byte offset where the edit starts
    # @param old_end_byte [Integer] byte offset where the old text ended
    # @param new_end_byte [Integer] byte offset where the new text ends
    # @param start_point [Hash] starting position as `{ row:, column: }`
    # @param old_end_point [Hash] old ending position as `{ row:, column: }`
    # @param new_end_point [Hash] new ending position as `{ row:, column: }`
    # @return [void]
    # @raise [NotAvailable] if the backend doesn't support incremental parsing
    # @see https://tree-sitter.github.io/tree-sitter/using-parsers#editing
    #
    # @example
    #   # Original: "x = 1"
    #   # Edited:   "x = 42"  (replaced "1" with "42" at byte 4)
    #   tree.edit(
    #     start_byte: 4,
    #     old_end_byte: 5,
    #     new_end_byte: 6,
    #     start_point: { row: 0, column: 4 },
    #     old_end_point: { row: 0, column: 5 },
    #     new_end_point: { row: 0, column: 6 }
    #   )
    def edit(start_byte:, old_end_byte:, new_end_byte:, start_point:, old_end_point:, new_end_point:)
      unless @impl.respond_to?(:edit)
        raise NotAvailable, "Incremental parsing not supported by current backend. " \
          "Use MRI (ruby_tree_sitter) or Rust (tree_stump) backend."
      end

      @impl.edit(
        start_byte: start_byte,
        old_end_byte: old_end_byte,
        new_end_byte: new_end_byte,
        start_point: start_point,
        old_end_point: old_end_point,
        new_end_point: new_end_point,
      )
    end

    # Check if the underlying implementation supports incremental parsing
    #
    # @return [Boolean] true if {#edit} can be called on this tree
    def supports_editing?
      @impl.respond_to?(:edit)
    end
  end

  # Represents a node in the syntax tree
  #
  # A Node represents a single element in the parsed AST. Each node has
  # a type (like "string", "number", "table", etc.) and may have child nodes.
  #
  # @example Traversing nodes
  #   root = tree.root_node
  #   root.each do |child|
  #     puts "Child type: #{child.type}"
  #     child.each { |grandchild| puts "  Grandchild: #{grandchild.type}" }
  #   end
  class Node
    # @api private
    def initialize(impl)
      @impl = impl
    end

    # Get the type name of this node
    #
    # The type corresponds to the grammar rule that produced this node
    # (e.g., "document", "table", "string_literal", "pair", etc.).
    #
    # @return [String] the node type
    # @example
    #   node.type  # => "table"
    def type
      @impl.type
    end

    # Iterate over child nodes
    #
    # @yieldparam child [Node] each child node
    # @return [Enumerator, nil] an enumerator if no block given, nil otherwise
    # @example With a block
    #   node.each { |child| puts child.type }
    #
    # @example Without a block
    #   children = node.each.to_a
    def each(&blk)
      return enum_for(:each) unless block_given?
      @impl.each { |child_impl| blk.call(Node.new(child_impl)) }
    end

    # Get the start position of this node in the source
    #
    # @return [Object] point object with row and column
    # @example
    #   node.start_point.row     # => 0
    #   node.start_point.column  # => 4
    def start_point
      @impl.start_point
    end

    # Get the end position of this node in the source
    #
    # @return [Object] point object with row and column
    # @example
    #   node.end_point.row     # => 0
    #   node.end_point.column  # => 10
    def end_point
      @impl.end_point
    end

    # Get the start byte offset of this node in the source
    #
    # @return [Integer] byte offset from beginning of source
    def start_byte
      @impl.start_byte
    end

    # Get the end byte offset of this node in the source
    #
    # @return [Integer] byte offset from beginning of source
    def end_byte
      @impl.end_byte
    end

    # Check if this node or any descendant has a parse error
    #
    # @return [Boolean] true if there is an error in the subtree
    def has_error?
      @impl.respond_to?(:has_error?) && @impl.has_error?
    end

    # Check if this node is a MISSING node (inserted by error recovery)
    #
    # @return [Boolean] true if this is a missing node
    def missing?
      @impl.respond_to?(:missing?) && @impl.missing?
    end

    # Get string representation of this node
    #
    # @return [String] string representation
    def to_s
      @impl.to_s
    end

    # Check if node responds to a method (includes delegation to @impl)
    #
    # @param method_name [Symbol] method to check
    # @param include_private [Boolean] include private methods
    # @return [Boolean]
    def respond_to_missing?(method_name, include_private = false)
      @impl.respond_to?(method_name, include_private) || super
    end

    # Delegate unknown methods to the underlying implementation
    #
    # This provides full compatibility with ruby_tree_sitter nodes
    # for methods not explicitly wrapped.
    #
    # @param method_name [Symbol] method to call
    # @param args [Array] arguments to pass
    # @param block [Proc] block to pass
    # @return [Object] result from the underlying implementation
    def method_missing(method_name, *args, **kwargs, &block)
      if @impl.respond_to?(method_name)
        @impl.public_send(method_name, *args, **kwargs, &block)
      else
        super
      end
    end
  end
end

TreeHaver::Version.class_eval do
  extend VersionGem::Basic
end
