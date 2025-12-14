# frozen_string_literal: true

module TreeHaver
  module Backends
    # Java backend for JRuby using java-tree-sitter
    #
    # This backend is designed to integrate with java-tree-sitter JARs on JRuby,
    # leveraging JRuby's native Java integration for optimal performance.
    #
    # @note This backend is currently in development and not yet fully implemented
    # @note Only available on JRuby
    module Java
      module_function

      # Attempt to append JARs from TREE_SITTER_JAVA_JARS_DIR to JRuby classpath
      #
      # If the environment variable is set and points to a directory, all .jar files
      # in that directory (recursively) are added to the JRuby classpath.
      #
      # @return [void]
      # @example
      #   ENV["TREE_SITTER_JAVA_JARS_DIR"] = "/path/to/java-tree-sitter/jars"
      #   TreeHaver::Backends::Java.add_jars_from_env!
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

      # Check if the Java backend is available
      #
      # Returns true if running on JRuby and java-tree-sitter classes can be detected.
      # Automatically attempts to load JARs from ENV["TREE_SITTER_JAVA_JARS_DIR"] if set.
      #
      # @return [Boolean] true if Java backend is available
      # @example
      #   if TreeHaver::Backends::Java.available?
      #     puts "Java backend is ready"
      #   end
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

      # Get capabilities supported by this backend
      #
      # @return [Hash{Symbol => Object}] capability map
      # @example
      #   TreeHaver::Backends::Java.capabilities
      #   # => { backend: :java, parse: false, query: false, bytes_field: true }
      def capabilities
        return {} unless available?
        {
          backend: :java,
          parse: false, # not implemented yet
          query: false,
          bytes_field: true,
        }
      end

      # Placeholder for Java-backed Language
      #
      # Will wrap java-tree-sitter Language objects when implemented.
      class Language
        # Load a language from a shared library
        #
        # @note Not yet implemented
        # @param _path [String] path to language library (unused)
        # @param symbol [String, nil] exported symbol name (unused)
        # @param name [String, nil] logical name (unused)
        # @raise [TreeHaver::NotAvailable] always raises until implementation is complete
        def self.from_library(_path, symbol: nil, name: nil)
          # keep parameters to satisfy keyword callers; unused for now
          raise TreeHaver::NotAvailable, "Java backend not available or not yet implemented"
        end

        class << self
          alias from_path from_library
        end
      end

      # Placeholder for Java-backed Parser
      #
      # Will wrap java-tree-sitter Parser objects when implemented.
      class Parser
        # Create a new parser instance
        #
        # @note Not yet implemented
        # @raise [TreeHaver::NotAvailable] always raises until implementation is complete
        def initialize
          raise TreeHaver::NotAvailable, "Java backend not available or not yet implemented"
        end
      end

      # Placeholder for Java-backed Tree
      #
      # Will wrap java-tree-sitter Tree objects when implemented.
      class Tree
      end

      # Placeholder for Java-backed Node
      #
      # Will wrap java-tree-sitter Node objects when implemented.
      class Node
      end
    end
  end
end
