# frozen_string_literal: true

module TreeHaver
  module Backends
    # MRI backend using the ruby_tree_sitter gem
    #
    # This backend wraps the ruby_tree_sitter gem, which is a native C extension
    # for MRI Ruby. It provides the most feature-complete tree-sitter integration
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
      class << self
        def available?
          return @loaded if @load_attempted # rubocop:disable ThreadSafety/ClassInstanceVariable
          @load_attempted = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          begin
            require "ruby_tree_sitter"

            @loaded = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          rescue LoadError
            @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          end
          @loaded # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # Get capabilities supported by this backend
        #
        # @return [Hash{Symbol => Object}] capability map
        # @example
        #   TreeHaver::Backends::MRI.capabilities
        #   # => { backend: :mri, query: true, bytes_field: true, incremental: true }
        def capabilities
          return {} unless available?
          {
            backend: :mri,
            query: true,
            bytes_field: true,
            incremental: true,
          }
        end
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
        class << self
          def from_path(path)
            raise TreeHaver::NotAvailable, "ruby_tree_sitter not available" unless MRI.available?
            ::TreeSitter::Language.load(path)
          end
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
        # @return [TreeHaver::Tree] wrapped tree
        def parse(source)
          tree = @parser.parse(source)
          TreeHaver::Tree.new(tree, source: source)
        end

        # Parse source code with optional incremental parsing
        #
        # @param old_tree [TreeHaver::Tree, nil] previous tree for incremental parsing
        # @param source [String] the source code to parse
        # @return [TreeHaver::Tree] wrapped tree
        def parse_string(old_tree, source)
          # Unwrap if TreeHaver::Tree to get inner tree for incremental parsing
          inner_old_tree = old_tree.respond_to?(:inner_tree) ? old_tree.inner_tree : old_tree
          tree = @parser.parse_string(inner_old_tree, source)
          TreeHaver::Tree.new(tree, source: source)
        end
      end
    end
  end
end
