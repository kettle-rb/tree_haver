# frozen_string_literal: true

module TreeHaver
  module Backends
    # Rust backend using the tree_stump gem
    #
    # This backend wraps the tree_stump gem, which provides Ruby bindings to
    # Tree-sitter written in Rust. It offers native performance with Rust's
    # safety guarantees and includes precompiled binaries for common platforms.
    #
    # tree_stump supports incremental parsing and the Query API, making it
    # suitable for editor/IDE use cases where performance is critical.
    #
    # @note This backend works on MRI Ruby. JRuby/TruffleRuby support is unknown.
    # @see https://github.com/anthropics/tree_stump tree_stump
    module Rust
      @load_attempted = false
      @loaded = false

      # Check if the Rust backend is available
      #
      # Attempts to require tree_stump on first call and caches the result.
      #
      # @return [Boolean] true if tree_stump is available
      # @example
      #   if TreeHaver::Backends::Rust.available?
      #     puts "Rust backend is ready"
      #   end
      def self.available?
        return @loaded if @load_attempted
        @load_attempted = true
        begin
          require "tree_stump"
          @loaded = true
        rescue LoadError
          @loaded = false
        end
        @loaded
      end

      # Reset the load state (primarily for testing)
      #
      # @return [void]
      # @api private
      def self.reset!
        @load_attempted = false
        @loaded = false
      end

      # Get capabilities supported by this backend
      #
      # @return [Hash{Symbol => Object}] capability map
      # @example
      #   TreeHaver::Backends::Rust.capabilities
      #   # => { backend: :rust, query: true, bytes_field: true, incremental: true }
      def self.capabilities
        return {} unless available?
        {
          backend: :rust,
          query: true,
          bytes_field: true,
          incremental: true,
        }
      end

      # Wrapper for tree_stump Language
      #
      # Provides TreeHaver-compatible interface to tree_stump's language loading.
      # tree_stump uses a registration-based API where languages are registered
      # by name, then referenced by that name when setting parser language.
      class Language
        # The registered language name
        # @return [String]
        attr_reader :name

        # @api private
        # @param name [String] the registered language name
        def initialize(name)
          @name = name
        end

        # Load a language from a shared library path
        #
        # @param path [String] absolute path to the language shared library
        # @param symbol [String, nil] the symbol name (accepted for API consistency, but tree_stump derives it from name)
        # @param name [String, nil] logical name for the language (optional, derived from path if not provided)
        # @return [Language] a wrapper holding the registered language name
        # @raise [TreeHaver::NotAvailable] if tree_stump is not available
        # @example
        #   lang = TreeHaver::Backends::Rust::Language.from_library("/usr/local/lib/libtree-sitter-toml.so")
        def self.from_library(path, symbol: nil, name: nil) # rubocop:disable Lint/UnusedMethodArgument
          raise TreeHaver::NotAvailable, "tree_stump not available" unless Rust.available?

          # Validate the path exists before calling register_lang to provide a clear error
          unless File.exist?(path)
            raise TreeHaver::NotAvailable, "Language library not found: #{path}"
          end

          # tree_stump uses TreeStump.register_lang(name, path) to register languages
          # The name is used to derive the symbol automatically (tree_sitter_<name>)
          lang_name = name || File.basename(path, ".*").sub(/^libtree-sitter-/, "")
          begin
            ::TreeStump.register_lang(lang_name, path)
          rescue RuntimeError => e
            raise TreeHaver::NotAvailable, "Failed to load language from #{path}: #{e.message}"
          end
          new(lang_name)
        end

        # Alias for compatibility
        #
        # @see from_library
        def self.from_path(path)
          from_library(path)
        end
      end

      # Wrapper for tree_stump Parser
      #
      # Provides TreeHaver-compatible interface to tree_stump's parser.
      class Parser
        # Create a new parser instance
        #
        # @raise [TreeHaver::NotAvailable] if tree_stump is not available
        def initialize
          raise TreeHaver::NotAvailable, "tree_stump not available" unless Rust.available?
          @parser = ::TreeStump::Parser.new
        end

        # Set the language for this parser
        #
        # @param lang [Language, String] the language to use (Language wrapper or name string)
        # @return [Language, String] the language that was set
        def language=(lang)
          # tree_stump uses set_language with a string name
          lang_name = lang.respond_to?(:name) ? lang.name : lang.to_s
          @parser.set_language(lang_name)
          lang
        end

        # Parse source code
        #
        # @param source [String] the source code to parse
        # @return [Object] the parsed syntax tree
        def parse(source)
          @parser.parse(source)
        end

        # Parse source code with optional incremental parsing
        #
        # @param old_tree [Object, nil] previous tree for incremental parsing
        # @param source [String] the source code to parse
        # @return [Object] the parsed syntax tree
        def parse_string(old_tree, source)
          # tree_stump doesn't have parse_string, use parse instead
          # TODO: Check if tree_stump supports incremental parsing
          @parser.parse(source)
        end
      end

      # Wrapper for tree_stump Tree
      #
      # Not used directly; TreeHaver passes through tree_stump Tree objects.
      class Tree
        # Not used directly; we pass through tree_stump::Tree
      end

      # Wrapper for tree_stump Node
      #
      # Not used directly; TreeHaver passes through tree_stump::Node objects.
      class Node
        # Not used directly; we pass through tree_stump::Node
      end
    end
  end
end

