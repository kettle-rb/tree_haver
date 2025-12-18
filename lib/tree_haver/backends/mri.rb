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
      # Wraps ::TreeSitter::Language from ruby_tree_sitter to provide a consistent
      # API across all backends.
      class Language
        include Comparable

        # The wrapped TreeSitter::Language object
        # @return [::TreeSitter::Language]
        attr_reader :inner_language

        # The backend this language is for
        # @return [Symbol]
        attr_reader :backend

        # The path this language was loaded from (if known)
        # @return [String, nil]
        attr_reader :path

        # The symbol name (if known)
        # @return [String, nil]
        attr_reader :symbol

        # @api private
        # @param lang [::TreeSitter::Language] the language object from ruby_tree_sitter
        # @param path [String, nil] path language was loaded from
        # @param symbol [String, nil] symbol name
        def initialize(lang, path: nil, symbol: nil)
          @inner_language = lang
          @backend = :mri
          @path = path
          @symbol = symbol
        end

        # Compare languages for equality
        #
        # MRI languages are equal if they have the same backend, path, and symbol.
        # Path and symbol uniquely identify a loaded language.
        #
        # @param other [Object] object to compare with
        # @return [Integer, nil] -1, 0, 1, or nil if not comparable
        def <=>(other)
          return unless other.is_a?(Language)
          return unless other.backend == @backend

          # Compare by path first, then symbol
          cmp = (@path || "") <=> (other.path || "")
          return cmp unless cmp.zero?

          (@symbol || "") <=> (other.symbol || "")
        end

        # Hash value for this language (for use in Sets/Hashes)
        # @return [Integer]
        def hash
          [@backend, @path, @symbol].hash
        end

        # Alias eql? to ==
        alias_method :eql?, :==

        # Convert to the underlying TreeSitter::Language for passing to parser
        #
        # @return [::TreeSitter::Language]
        def to_language
          @inner_language
        end
        alias_method :to_ts_language, :to_language

        # Load a language from a shared library (preferred method)
        #
        # @param path [String] absolute path to the language shared library
        # @param symbol [String] the exported symbol name (e.g., "tree_sitter_json")
        # @param name [String, nil] optional language name (unused by MRI backend)
        # @return [Language] wrapped language handle
        # @raise [TreeHaver::NotAvailable] if ruby_tree_sitter is not available
        # @example
        #   lang = TreeHaver::Backends::MRI::Language.from_library("/path/to/lib.so", symbol: "tree_sitter_json")
        class << self
          def from_library(path, symbol: nil, name: nil)
            raise TreeHaver::NotAvailable, "ruby_tree_sitter not available" unless MRI.available?

            # ruby_tree_sitter's TreeSitter::Language.load takes (language_name, path_to_so)
            # where language_name is the language identifier (e.g., "toml", "json")
            # NOT the full symbol name (e.g., NOT "tree_sitter_toml")
            # and path_to_so is the full path to the .so file
            #
            # If name is not provided, derive it from symbol by stripping "tree_sitter_" prefix
            language_name = name || symbol&.sub(/\Atree_sitter_/, "")
            ts_lang = ::TreeSitter::Language.load(language_name, path)
            new(ts_lang, path: path, symbol: symbol)
          rescue NameError => e
            # TreeSitter constant doesn't exist - backend not loaded
            raise TreeHaver::NotAvailable, "ruby_tree_sitter not available: #{e.message}"
          rescue Exception => e # rubocop:disable Lint/RescueException
            # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
            # We rescue Exception and check the class name dynamically to avoid NameError
            # at parse time when TreeSitter constant isn't loaded yet
            if defined?(TreeSitter::TreeSitterError) && e.is_a?(TreeSitter::TreeSitterError)
              raise TreeHaver::NotAvailable, "Could not load language: #{e.message}"
            else
              raise # Re-raise if it's not a TreeSitter error
            end
          end

          # Load a language from a shared library path (legacy method)
          #
          # @param path [String] absolute path to the language shared library
          # @param symbol [String] the exported symbol name (e.g., "tree_sitter_json")
          # @return [Language] wrapped language handle
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
        rescue Exception => e # rubocop:disable Lint/RescueException
          # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
          # We rescue Exception and check the class name dynamically to avoid NameError
          # at parse time when TreeSitter constant isn't loaded yet
          if defined?(TreeSitter::TreeSitterError) && e.is_a?(TreeSitter::TreeSitterError)
            raise TreeHaver::NotAvailable, "Could not create parser: #{e.message}"
          else
            raise # Re-raise if it's not a TreeSitter error
          end
        end

        # Set the language for this parser
        #
        # Note: TreeHaver::Parser unwraps language objects before calling this method.
        # This backend receives raw ::TreeSitter::Language objects, never wrapped ones.
        #
        # @param lang [::TreeSitter::Language] the language to use (already unwrapped)
        # @return [::TreeSitter::Language] the language that was set
        # @raise [TreeHaver::NotAvailable] if setting language fails
        def language=(lang)
          # lang is already unwrapped by TreeHaver::Parser, use directly
          @parser.language = lang
          # Verify it was set
          raise TreeHaver::NotAvailable, "Language not set correctly" if @parser.language.nil?

          # Return the language object
          lang
        rescue Exception => e # rubocop:disable Lint/RescueException
          # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
          # We rescue Exception and check the class name dynamically to avoid NameError
          # at parse time when TreeSitter constant isn't loaded yet
          if defined?(TreeSitter::TreeSitterError) && e.is_a?(TreeSitter::TreeSitterError)
            raise TreeHaver::NotAvailable, "Could not set language: #{e.message}"
          else
            raise # Re-raise if it's not a TreeSitter error
          end
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
        rescue Exception => e # rubocop:disable Lint/RescueException
          # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
          # We rescue Exception and check the class name dynamically to avoid NameError
          # at parse time when TreeSitter constant isn't loaded yet
          if defined?(TreeSitter::TreeSitterError) && e.is_a?(TreeSitter::TreeSitterError)
            raise TreeHaver::NotAvailable, "Could not parse source: #{e.message}"
          else
            raise # Re-raise if it's not a TreeSitter error
          end
        end

        # Parse source code with optional incremental parsing
        #
        # Note: old_tree should already be unwrapped by TreeHaver::Parser before reaching this method.
        # The backend receives the raw inner tree (::TreeSitter::Tree or nil), not a wrapped TreeHaver::Tree.
        #
        # @param old_tree [::TreeSitter::Tree, nil] previous tree for incremental parsing (already unwrapped)
        # @param source [String] the source code to parse
        # @return [::TreeSitter::Tree] raw tree (NOT wrapped - wrapping happens in TreeHaver::Parser)
        # @raise [TreeHaver::NotAvailable] if parsing fails
        def parse_string(old_tree, source)
          # old_tree is already unwrapped by TreeHaver::Parser, pass it directly
          # Return raw tree - TreeHaver::Parser will wrap it
          @parser.parse_string(old_tree, source)
        rescue Exception => e # rubocop:disable Lint/RescueException
          # TreeSitter errors inherit from Exception (not StandardError) in ruby_tree_sitter v2+
          # We rescue Exception and check the class name dynamically to avoid NameError
          # at parse time when TreeSitter constant isn't loaded yet
          if defined?(TreeSitter::TreeSitterError) && e.is_a?(TreeSitter::TreeSitterError)
            raise TreeHaver::NotAvailable, "Could not parse source: #{e.message}"
          else
            raise # Re-raise if it's not a TreeSitter error
          end
        end
      end
    end
  end
end
