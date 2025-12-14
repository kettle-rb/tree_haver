# frozen_string_literal: true

module TreeHaver
  module Backends
    module MRI
      @load_attempted = false
      @loaded = false

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

      def self.capabilities
        return {} unless available?
        {
          backend: :mri,
          query: true,
          bytes_field: true,
        }
      end

      class Language
        def self.from_path(path)
          raise TreeHaver::NotAvailable, "ruby_tree_sitter not available" unless MRI.available?
          # ruby_tree_sitter expects Fiddle::Handle path for language .so/.dylib
          ::TreeSitter::Language.load(path)
        end
      end

      class Parser
        def initialize
          raise TreeHaver::NotAvailable, "ruby_tree_sitter not available" unless MRI.available?
          @parser = ::TreeSitter::Parser.new
        end

        def language=(lang)
          @parser.language = lang
        end

        def parse(source)
          @parser.parse(source)
        end
      end

      class Tree
        # Not used directly; we pass through ruby_tree_sitter::Tree
      end

      class Node
        # Not used directly; we pass through ruby_tree_sitter::Node
      end
    end
  end
end
