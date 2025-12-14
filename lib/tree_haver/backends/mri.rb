# frozen_string_literal: true

module TreeHaver
  module Backends
    # MRI backend using the ruby_tree_sitter gem
    #
    # This backend wraps the ruby_tree_sitter gem, which is a native C extension
    # for MRI Ruby. It provides the most feature-complete Tree-sitter integration
    # on MRI, including support for the Query API.
    #
    # @note This backend only works on MRI Ruby, not JRuby or TruffleRuby
    # @see https://github.com/Faveod/ruby-tree-sitter ruby_tree_sitter
    module MRI
      @load_attempted = false
      @loaded = false

      # Check if the MRI backend is available
      #
      # Attempts to require ruby_tree_sitter on first call and caches the result.
      #
      # @return [Boolean] true if ruby_tree_sitter is available
      # @example
      #   if TreeHaver::Backends::MRI.available?
      #     puts "MRI backend is ready"
      #   end
      def self.available?
        return @loaded if @load_attempted
        @load_attempted = true
        begin
          require "ruby_tree_sitter"
          @loaded = true
        rescue LoadError
          @loaded = false
        end
        @loaded
      end

      # Get capabilities supported by this backend
      #
      # @return [Hash{Symbol => Object}] capability map
      # @example
      #   TreeHaver::Backends::MRI.capabilities
      #   # => { backend: :mri, query: true, bytes_field: true, incremental: true }
      def self.capabilities
        return {} unless available?
        {
          backend: :mri,
          query: true,
          bytes_field: true,
          incremental: true,
        }
      end

      # Wrapper for ruby_tree_sitter Language
      #
      # This is a thin pass-through to ::TreeSitter::Language from ruby_tree_sitter.
      class Language
        # Load a language from a shared library path
        #
        # @param path [String] absolute path to the language shared library
        # @return [::TreeSitter::Language] the loaded language handle
        # @raise [TreeHaver::NotAvailable] if ruby_tree_sitter is not available
        # @example
        #   lang = TreeHaver::Backends::MRI::Language.from_path("/usr/local/lib/libtree-sitter-toml.so")
        def self.from_path(path)
          raise TreeHaver::NotAvailable, "ruby_tree_sitter not available" unless MRI.available?
          # ruby_tree_sitter expects Fiddle::Handle path for language .so/.dylib
          ::TreeSitter::Language.load(path)
        end
      end

      # Wrapper for ruby_tree_sitter Parser
      #
      # This is a thin pass-through to ::TreeSitter::Parser from ruby_tree_sitter.
      class Parser
        # Create a new parser instance
        #
        # @raise [TreeHaver::NotAvailable] if ruby_tree_sitter is not available
        def initialize
          raise TreeHaver::NotAvailable, "ruby_tree_sitter not available" unless MRI.available?
          @parser = ::TreeSitter::Parser.new
        end

        # Set the language for this parser
        #
        # @param lang [::TreeSitter::Language] the language to use
        # @return [::TreeSitter::Language] the language that was set
        def language=(lang)
          @parser.language = lang
        end

        # Parse source code
        #
        # @param source [String] the source code to parse
        # @return [::TreeSitter::Tree] the parsed syntax tree
        def parse(source)
          @parser.parse(source)
        end

        # Parse source code with optional incremental parsing
        #
        # @param old_tree [::TreeSitter::Tree, nil] previous tree for incremental parsing
        # @param source [String] the source code to parse
        # @return [::TreeSitter::Tree] the parsed syntax tree
        def parse_string(old_tree, source)
          @parser.parse_string(old_tree, source)
        end
      end

      # Wrapper for ruby_tree_sitter Tree
      #
      # Not used directly; TreeHaver passes through ::TreeSitter::Tree objects.
      class Tree
        # Not used directly; we pass through ruby_tree_sitter::Tree
      end

      # Wrapper for ruby_tree_sitter Node
      #
      # Not used directly; TreeHaver passes through ::TreeSitter::Node objects.
      class Node
        # Not used directly; we pass through ruby_tree_sitter::Node
      end
    end
  end
end
