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
            require "tree_sitter" # Note: gem is ruby_tree_sitter but requires tree_sitter

            @loaded = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          rescue LoadError
            @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          end
          @loaded # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # Reset the load state (primarily for testing)
        #
        # @return [void]
        # @api private
        def reset!
          @load_attempted = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
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
        # Load a language from a shared library (preferred method)
        #
        # @param path [String] absolute path to the language shared library
        # @param symbol [String] the exported symbol name (e.g., "tree_sitter_json")
        # @param name [String, nil] optional language name (unused by MRI backend)
        # @return [::TreeSitter::Language] the loaded language handle
        # @raise [TreeHaver::NotAvailable] if ruby_tree_sitter is not available
        # @example
        #   lang = TreeHaver::Backends::MRI::Language.from_library("/path/to/lib.so", symbol: "tree_sitter_json")
        class << self
          def from_library(path, symbol: nil, name: nil)
            raise TreeHaver::NotAvailable, "ruby_tree_sitter not available" unless MRI.available?

            # ruby_tree_sitter's TreeSitter::Language.load takes (language_name, path_to_so)
            # where language_name is the exported symbol name (e.g., "tree_sitter_json")
            # and path_to_so is the full path to the .so file
            ::TreeSitter::Language.load(name || symbol, path)
          rescue NameError => e
            # TreeSitter constant doesn't exist - backend not loaded
            raise TreeHaver::NotAvailable, "ruby_tree_sitter not available: #{e.message}"
          rescue TreeSitter::TreeSitterError => e
            # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
            # This includes: ParserNotFoundError, LanguageLoadError, SymbolNotFoundError, etc.
            raise TreeHaver::NotAvailable, "Could not load language: #{e.message}"
          end

          # Load a language from a shared library path (legacy method)
          #
          # @param path [String] absolute path to the language shared library
          # @param symbol [String] the exported symbol name (e.g., "tree_sitter_json")
          # @return [::TreeSitter::Language] the loaded language handle
          # @deprecated Use {from_library} instead
          def from_path(path, symbol: nil)
            from_library(path, symbol: symbol)
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
        rescue NameError => e
          # TreeSitter constant doesn't exist - backend not loaded
          raise TreeHaver::NotAvailable, "ruby_tree_sitter not available: #{e.message}"
        rescue TreeSitter::TreeSitterError => e
          # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
          raise TreeHaver::NotAvailable, "Could not create parser: #{e.message}"
        end

        # Set the language for this parser
        #
        # @param lang [::TreeSitter::Language] the language to use
        # @return [::TreeSitter::Language] the language that was set
        # @raise [TreeHaver::NotAvailable] if setting language fails
        def language=(lang)
          @parser.language = lang
          # Verify it was set
          raise TreeHaver::NotAvailable, "Language not set correctly" if @parser.language.nil?

          # Return the original language object, not what ruby_tree_sitter returns
          # ruby_tree_sitter may return a different object, but we want consistency
          lang
        rescue TreeSitter::TreeSitterError => e
          # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
          raise TreeHaver::NotAvailable, "Could not set language: #{e.message}"
        end

        # Parse source code
        #
        # ruby_tree_sitter provides parse_string for string input
        #
        # @param source [String] the source code to parse
        # @return [::TreeSitter::Tree] raw tree (NOT wrapped - wrapping happens in TreeHaver::Parser)
        # @raise [TreeHaver::NotAvailable] if parsing returns nil (usually means language not set)
        def parse(source)
          # ruby_tree_sitter's parse_string(old_tree, string) method
          # Pass nil for old_tree (initial parse)
          # Return raw tree - TreeHaver::Parser will wrap it
          tree = @parser.parse_string(nil, source)
          raise TreeHaver::NotAvailable, "Parse returned nil - is language set?" if tree.nil?
          tree
        rescue TreeSitter::TreeSitterError => e
          # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
          raise TreeHaver::NotAvailable, "Could not parse source: #{e.message}"
        end

        # Parse source code with optional incremental parsing
        #
        # @param old_tree [TreeHaver::Tree, nil] previous tree for incremental parsing
        # @param source [String] the source code to parse
        # @return [::TreeSitter::Tree] raw tree (NOT wrapped - wrapping happens in TreeHaver::Parser)
        # @raise [TreeHaver::NotAvailable] if parsing fails
        def parse_string(old_tree, source)
          # Unwrap if TreeHaver::Tree to get inner tree for incremental parsing
          inner_old_tree = old_tree.respond_to?(:inner_tree) ? old_tree.inner_tree : old_tree
          # Return raw tree - TreeHaver::Parser will wrap it
          @parser.parse_string(inner_old_tree, source)
        rescue TreeSitter::TreeSitterError => e
          # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
          raise TreeHaver::NotAvailable, "Could not parse source: #{e.message}"
        end
      end
    end
  end
end
