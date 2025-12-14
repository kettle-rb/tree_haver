# frozen_string_literal: true

module TreeHaver
  module Backends
    # Optional JRuby backend implemented by wrapping java-tree-sitter.
    # At this stage, only availability detection and diagnostics are provided.
    module Java
      module_function

      # Attempt to append JARs from TREE_SITTER_JAVA_JARS_DIR to JRuby classpath.
      def add_jars_from_env!
        dir = ENV["TREE_SITTER_JAVA_JARS_DIR"]
        return unless dir && Dir.exist?(dir)
        require "java"
        Dir[File.join(dir, "**", "*.jar")].each do |jar|
          next if $CLASSPATH.include?(jar)
          $CLASSPATH << jar
        end
      rescue LoadError
        # ignore; not JRuby or Java bridge not available
      end

      # Whether the Java backend can be used in the current process
      def available?
        return false unless defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
        begin
          require "java"
        rescue LoadError
          return false
        end

        # Optionally augment classpath from env
        add_jars_from_env!

        # Try to detect presence of java-tree-sitter classes.
        # We keep this heuristic lenient: if classes are not present, report unavailable.
        begin
          # Try a few likely packages; if none resolve, backend is not available.
          # These constants may vary depending on the published artifact; adjust later when wiring.
          return true if defined?(Java::Org::Treesitter)
          return true if defined?(Java::Com::Github::Treesitter)
        rescue NameError
          # fall through to false
        end
        false
      end

      def capabilities
        return {} unless available?
        {
          backend: :java,
          parse: false, # not implemented yet
          query: false,
          bytes_field: true,
        }
      end

      class Language
        # Accept facade-compatible keyword arguments to avoid ArgumentError in callers.
        # Currently always raises NotAvailable until the Java backend is wired.
        def self.from_library(_path, symbol: nil, name: nil)
          # keep parameters to satisfy keyword callers; unused for now
          raise TreeHaver::NotAvailable, "Java backend not available or not yet implemented"
        end

        class << self
          alias from_path from_library
        end
      end

      class Parser
        def initialize
          raise TreeHaver::NotAvailable, "Java backend not available or not yet implemented"
        end
      end

      class Tree
      end

      class Node
      end
    end
  end
end
