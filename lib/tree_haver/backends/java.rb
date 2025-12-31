# frozen_string_literal: true

module TreeHaver
  module Backends
    # Java backend for JRuby using java-tree-sitter (jtreesitter)
    #
    # This backend integrates with java-tree-sitter JARs on JRuby,
    # leveraging JRuby's native Java integration for optimal performance.
    #
    # java-tree-sitter provides Java bindings to tree-sitter and supports:
    # - Parsing source code into syntax trees
    # - Incremental parsing via Parser.parse(Tree, String)
    # - The Query API for pattern matching
    # - Tree editing for incremental re-parsing
    #
    # == Platform Compatibility
    #
    # - MRI Ruby: ✗ Not available (no JVM)
    # - JRuby: ✓ Full support (native Java integration)
    # - TruffleRuby: ✗ Not available (java-tree-sitter requires JRuby's Java interop)
    #
    # == Installation
    #
    # 1. Download the JAR from Maven Central:
    #    https://central.sonatype.com/artifact/io.github.tree-sitter/jtreesitter
    #
    # 2. Set the environment variable to point to the JAR directory:
    #    export TREE_SITTER_JAVA_JARS_DIR=/path/to/jars
    #
    # 3. Use JRuby to run your code:
    #    jruby -e "require 'tree_haver'; puts TreeHaver::Backends::Java.available?"
    #
    # @see https://github.com/tree-sitter/java-tree-sitter source
    # @see https://tree-sitter.github.io/java-tree-sitter java-tree-sitter documentation
    # @see https://central.sonatype.com/artifact/io.github.tree-sitter/jtreesitter Maven Central
    module Java
      # The Java package for java-tree-sitter
      JAVA_PACKAGE = "io.github.treesitter.jtreesitter"

      @load_attempted = false
      @loaded = false
      @java_classes = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable
      @runtime_lookup = nil  # Cached SymbolLookup for libtree-sitter.so

      module_function

      # Get the cached runtime library SymbolLookup
      # @return [Object, nil] the SymbolLookup for libtree-sitter.so
      # @api private
      def runtime_lookup
        @runtime_lookup
      end

      # Set the cached runtime library SymbolLookup
      # @param lookup [Object] the SymbolLookup
      # @api private
      def runtime_lookup=(lookup)
        @runtime_lookup = lookup
      end

      # Attempt to append JARs from TREE_SITTER_JAVA_JARS_DIR to JRuby classpath
      # and configure native library path from TREE_SITTER_RUNTIME_LIB
      #
      # If the environment variable is set and points to a directory, all .jar files
      # in that directory (recursively) are added to the JRuby classpath.
      #
      # @return [void]
      # @example
      #   ENV["TREE_SITTER_JAVA_JARS_DIR"] = "/path/to/java-tree-sitter/jars"
      #   TreeHaver::Backends::Java.add_jars_from_env!
      def add_jars_from_env!
        # :nocov:
        # This method requires JRuby and cannot be tested on MRI/CRuby.
        # JRuby-specific CI jobs would test this code.
        require "java"

        # Add JARs to classpath
        dir = ENV["TREE_SITTER_JAVA_JARS_DIR"]
        if dir && Dir.exist?(dir)
          Dir[File.join(dir, "**", "*.jar")].each do |jar|
            next if $CLASSPATH.include?(jar)
            $CLASSPATH << jar
          end
        end

        # Configure native library path for libtree-sitter
        # java-tree-sitter uses JNI and needs to find the native library
        configure_native_library_path!
        # :nocov:
      rescue LoadError
        # ignore; not JRuby or Java bridge not available
      end

      # Configure java.library.path to include the directory containing libtree-sitter
      #
      # @return [void]
      # @api private
      def configure_native_library_path!
        # :nocov:
        # This method requires JRuby and cannot be tested on MRI/CRuby.
        lib_path = ENV["TREE_SITTER_RUNTIME_LIB"]
        return unless lib_path && File.exist?(lib_path)

        lib_dir = File.dirname(lib_path)
        current_path = java.lang.System.getProperty("java.library.path") || ""

        unless current_path.include?(lib_dir)
          new_path = current_path.empty? ? lib_dir : "#{lib_dir}:#{current_path}"
          java.lang.System.setProperty("java.library.path", new_path)

          # Also set jna.library.path in case it uses JNA
          java.lang.System.setProperty("jna.library.path", new_path)
        end
        # :nocov:
      rescue => _error
        # Ignore errors setting library path
      end

      # Check if the Java backend is available
      #
      # Returns true if running on JRuby and java-tree-sitter classes can be loaded.
      # Automatically attempts to load JARs from ENV["TREE_SITTER_JAVA_JARS_DIR"] if set.
      #
      # @return [Boolean] true if Java backend is available
      # @example
      #   if TreeHaver::Backends::Java.available?
      #     puts "Java backend is ready"
      #   end
      def available?
        return @loaded if @load_attempted
        @load_attempted = true
        @loaded = false
        @load_error = nil

        return false unless defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"

        # :nocov:
        # Everything below requires JRuby and cannot be tested on MRI/CRuby.
        # JRuby-specific CI jobs would test this code.
        begin
          require "java"
        rescue LoadError
          @load_error = "JRuby java bridge not available"
          return false
        end

        # Optionally augment classpath and configure native library path
        add_jars_from_env!

        # Try to load the java-tree-sitter classes
        # Load Parser first as it doesn't trigger native library loading
        # Language class triggers native lib loading in its static initializer
        begin
          # These classes don't require native library initialization
          @java_classes[:Parser] = ::Java::IoGithubTreesitterJtreesitter::Parser
          @java_classes[:Tree] = ::Java::IoGithubTreesitterJtreesitter::Tree
          @java_classes[:Node] = ::Java::IoGithubTreesitterJtreesitter::Node
          @java_classes[:InputEdit] = ::Java::IoGithubTreesitterJtreesitter::InputEdit
          @java_classes[:Point] = ::Java::IoGithubTreesitterJtreesitter::Point

          # Language class may fail if native library isn't found - try it last
          # and provide a helpful error message
          begin
            @java_classes[:Language] = ::Java::IoGithubTreesitterJtreesitter::Language
          rescue NameError => e
            # Language failed but other classes loaded - native lib issue
            @load_error = "Language class failed to initialize (native library issue): #{e.message}"
            # Clear loaded classes since we can't fully function without Language
            @java_classes.clear
            return false
          end

          @loaded = true
        rescue NameError => e
          @load_error = "java-tree-sitter classes not found: #{e.message}"
          @loaded = false
        end

        @loaded
        # :nocov:
      end

      # Get the last load error message (for debugging)
      #
      # @return [String, nil] the error message or nil if no error
      def load_error
        @load_error
      end

      # Reset the load state (primarily for testing)
      #
      # @return [void]
      # @api private
      def reset!
        @load_attempted = false
        @loaded = false
        @load_error = nil
        @java_classes = {}
      end

      # Get the loaded Java classes
      #
      # @return [Hash] the Java class references
      # @api private
      def java_classes
        @java_classes
      end

      # Get capabilities supported by this backend
      #
      # @return [Hash{Symbol => Object}] capability map
      # @example
      #   TreeHaver::Backends::Java.capabilities
      #   # => { backend: :java, parse: true, query: true, bytes_field: true, incremental: true }
      def capabilities
        # :nocov:
        # This method returns meaningful data only on JRuby when java-tree-sitter is available.
        return {} unless available?
        {
          backend: :java,
          parse: true,
          query: true, # java-tree-sitter supports the Query API
          bytes_field: true,
          incremental: true, # java-tree-sitter supports Parser.parse(Tree, String)
        }
        # :nocov:
      end

      # Wrapper for java-tree-sitter Language
      #
      # @see https://tree-sitter.github.io/java-tree-sitter/io/github/treesitter/jtreesitter/Language.html
      #
      # :nocov:
      # All Java backend implementation classes require JRuby and cannot be tested on MRI/CRuby.
      # JRuby-specific CI jobs would test this code.
      class Language
        include Comparable

        attr_reader :impl

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
        def initialize(impl, path: nil, symbol: nil)
          @impl = impl
          @backend = :java
          @path = path
          @symbol = symbol
        end

        # Compare languages for equality
        #
        # Java languages are equal if they have the same backend, path, and symbol.
        # Path and symbol uniquely identify a loaded language.
        #
        # @param other [Object] object to compare with
        # @return [Integer, nil] -1, 0, 1, or nil if not comparable
        def <=>(other)
          return unless other.is_a?(Language)
          return unless other.backend == @backend

          # Compare by path first, then symbol
          cmp = (@path || "") <=> (other.path || "")
          return cmp if cmp.nonzero?

          (@symbol || "") <=> (other.symbol || "")
        end

        # Hash value for this language (for use in Sets/Hashes)
        # @return [Integer]
        def hash
          [@backend, @path, @symbol].hash
        end

        # Alias eql? to ==
        alias_method :eql?, :==

        # Load a language from a shared library
        #
        # There are three ways java-tree-sitter can load shared libraries:
        #
        # 1. Libraries in OS library search path (LD_LIBRARY_PATH on Linux,
        #    DYLD_LIBRARY_PATH on macOS, PATH on Windows) - loaded via
        #    SymbolLookup.libraryLookup(String, Arena)
        #
        # 2. Libraries in java.library.path - loaded via SymbolLookup.loaderLookup()
        #
        # 3. Custom NativeLibraryLookup implementation (e.g., for JARs)
        #
        # @param path [String] path to language shared library (.so/.dylib) or library name
        # @param symbol [String, nil] exported symbol name (e.g., "tree_sitter_toml")
        # @param name [String, nil] logical name (used to derive symbol if not provided)
        # @return [Language] the loaded language
        # @raise [TreeHaver::NotAvailable] if Java backend is not available
        # @example Load by path
        #   lang = TreeHaver::Backends::Java::Language.from_library(
        #     "/usr/lib/libtree-sitter-toml.so",
        #     symbol: "tree_sitter_toml"
        #   )
        # @example Load by name (searches LD_LIBRARY_PATH)
        #   lang = TreeHaver::Backends::Java::Language.from_library(
        #     "tree-sitter-toml",
        #     symbol: "tree_sitter_toml"
        #   )
        class << self
          def from_library(path, symbol: nil, name: nil)
            raise TreeHaver::NotAvailable, "Java backend not available" unless Java.available?

            # Use shared utility for consistent symbol derivation across backends
            # If symbol not provided, derive from name or path
            sym = symbol || LibraryPathUtils.derive_symbol_from_path(path)
            # If name was provided, use it to override the derived symbol
            sym = "tree_sitter_#{name}" if name && !symbol

            begin
              arena = ::Java::JavaLangForeign::Arena.global
              symbol_lookup_class = ::Java::JavaLangForeign::SymbolLookup

              # IMPORTANT: Load libtree-sitter.so FIRST by name so its symbols are available
              # Grammar libraries need symbols like ts_language_version from the runtime
              # We cache this lookup at the module level
              unless Java.runtime_lookup
                # Use libraryLookup(String, Arena) to search LD_LIBRARY_PATH
                Java.runtime_lookup = symbol_lookup_class.libraryLookup("libtree-sitter.so", arena)
              end

              # Now load the grammar library
              if File.exist?(path)
                # Explicit path provided - use libraryLookup(Path, Arena)
                java_path = ::Java::JavaNioFile::Paths.get(path)
                grammar_lookup = symbol_lookup_class.libraryLookup(java_path, arena)
              else
                # Library name provided - use libraryLookup(String, Arena) to search
                # LD_LIBRARY_PATH / DYLD_LIBRARY_PATH / PATH
                grammar_lookup = symbol_lookup_class.libraryLookup(path, arena)
              end

              # Chain the lookups: grammar first, then runtime library for ts_* symbols
              # This makes ts_language_version available when Language.load() needs it
              combined_lookup = grammar_lookup.or(Java.runtime_lookup)

              java_lang = Java.java_classes[:Language].load(combined_lookup, sym)
              new(java_lang, path: path, symbol: symbol)
            rescue ::Java::JavaLang::RuntimeException => e
              cause = e.cause
              root_cause = cause&.cause || cause

              error_msg = "Failed to load language '#{sym}' from #{path}: #{e.message}"
              if root_cause.is_a?(::Java::JavaLang::UnsatisfiedLinkError)
                unresolved = root_cause.message.to_s
                if unresolved.include?("ts_language_version")
                  # This specific symbol was renamed in tree-sitter 0.24
                  error_msg += "\n\nVersion mismatch detected: The grammar was built against " \
                    "tree-sitter < 0.24 (uses ts_language_version), but your runtime library " \
                    "is tree-sitter >= 0.24 (uses ts_language_abi_version).\n\n" \
                    "Solutions:\n" \
                    "1. Rebuild the grammar against your version of tree-sitter\n" \
                    "2. Install a matching version of tree-sitter (< 0.24)\n" \
                    "3. Find a pre-built grammar compatible with tree-sitter 0.24+"
                elsif unresolved.include?("ts_language") || unresolved.include?("ts_parser")
                  error_msg += "\n\nThe grammar library has unresolved tree-sitter symbols. " \
                    "Ensure libtree-sitter.so is in LD_LIBRARY_PATH and version-compatible " \
                    "with the grammar."
                end
              end
              raise TreeHaver::NotAvailable, error_msg
            rescue ::Java::JavaLang::UnsatisfiedLinkError => e
              raise TreeHaver::NotAvailable,
                "Native library error loading #{path}: #{e.message}. " \
                  "Ensure the library is in LD_LIBRARY_PATH."
            rescue ::Java::JavaLang::IllegalArgumentException => e
              raise TreeHaver::NotAvailable,
                "Could not find library '#{path}': #{e.message}. " \
                  "Ensure it's in LD_LIBRARY_PATH or provide an absolute path."
            end
          end

          # Load a language by name from java-tree-sitter grammar JARs
          #
          # This method loads grammars that are packaged as java-tree-sitter JARs
          # from Maven Central. These JARs include the native grammar library
          # pre-built for Java's Foreign Function API.
          #
          # @param name [String] the language name (e.g., "java", "python", "toml")
          # @return [Language] the loaded language
          # @raise [TreeHaver::NotAvailable] if the language JAR is not available
          #
          # @example
          #   # First, add the grammar JAR to TREE_SITTER_JAVA_JARS_DIR:
          #   # tree-sitter-toml-0.23.2.jar from Maven Central
          #   lang = TreeHaver::Backends::Java::Language.load_by_name("toml")
          def load_by_name(name)
            raise TreeHaver::NotAvailable, "Java backend not available" unless Java.available?

            begin
              # java-tree-sitter's Language.load(String) searches for the language
              # in the classpath using standard naming conventions
              java_lang = Java.java_classes[:Language].load(name)
              new(java_lang, symbol: "tree_sitter_#{name}")
            rescue ::Java::JavaLang::RuntimeException => e
              raise TreeHaver::NotAvailable,
                "Failed to load language '#{name}': #{e.message}. " \
                  "Ensure the grammar JAR (e.g., tree-sitter-#{name}-X.Y.Z.jar) " \
                  "is in TREE_SITTER_JAVA_JARS_DIR."
            end
          end
        end

        class << self
          alias_method :from_path, :from_library
        end
      end

      # Wrapper for java-tree-sitter Parser
      #
      # @see https://tree-sitter.github.io/java-tree-sitter/io/github/treesitter/jtreesitter/Parser.html
      class Parser
        # Create a new parser instance
        #
        # @raise [TreeHaver::NotAvailable] if Java backend is not available
        def initialize
          raise TreeHaver::NotAvailable, "Java backend not available" unless Java.available?
          @parser = Java.java_classes[:Parser].new
        end

        # Set the language for this parser
        #
        # Note: TreeHaver::Parser unwraps language objects before calling this method.
        # This backend receives the Language wrapper's inner impl (java Language object).
        #
        # @param lang [Object] the Java language object (already unwrapped)
        # @return [void]
        def language=(lang)
          # lang is already unwrapped by TreeHaver::Parser
          @parser.language = lang
        end

        # Parse source code
        #
        # @param source [String] the source code to parse
        # @return [Tree] raw backend tree (wrapping happens in TreeHaver::Parser)
        def parse(source)
          java_tree = @parser.parse(source)
          # Return raw Java::Tree - TreeHaver::Parser will wrap it
          Tree.new(java_tree)
        end

        # Parse source code with optional incremental parsing
        #
        # Note: old_tree is already unwrapped by TreeHaver::Parser before reaching this method.
        # The backend receives the raw Tree wrapper's impl, not a TreeHaver::Tree.
        #
        # When old_tree is provided and has been edited, tree-sitter will reuse
        # unchanged nodes for better performance.
        #
        # @param old_tree [Tree, nil] previous backend tree for incremental parsing (already unwrapped)
        # @param source [String] the source code to parse
        # @return [Tree] raw backend tree (wrapping happens in TreeHaver::Parser)
        # @see https://tree-sitter.github.io/java-tree-sitter/io/github/treesitter/jtreesitter/Parser.html#parse(io.github.treesitter.jtreesitter.Tree,java.lang.String)
        def parse_string(old_tree, source)
          # old_tree is already unwrapped to Tree wrapper's impl by TreeHaver::Parser
          if old_tree
            java_old_tree = old_tree.is_a?(Tree) ? old_tree.impl : old_tree
            java_tree = @parser.parse(java_old_tree, source)
          else
            java_tree = @parser.parse(source)
          end
          # Return raw Java::Tree - TreeHaver::Parser will wrap it
          Tree.new(java_tree)
        end
      end

      # Wrapper for java-tree-sitter Tree
      #
      # @see https://tree-sitter.github.io/java-tree-sitter/io/github/treesitter/jtreesitter/Tree.html
      class Tree
        attr_reader :impl

        # @api private
        def initialize(impl)
          @impl = impl
        end

        # Get the root node of the tree
        #
        # @return [Node] the root node
        def root_node
          Node.new(@impl.rootNode)
        end

        # Mark the tree as edited for incremental re-parsing
        #
        # @param start_byte [Integer] byte offset where the edit starts
        # @param old_end_byte [Integer] byte offset where the old text ended
        # @param new_end_byte [Integer] byte offset where the new text ends
        # @param start_point [Hash] starting position as `{ row:, column: }`
        # @param old_end_point [Hash] old ending position as `{ row:, column: }`
        # @param new_end_point [Hash] new ending position as `{ row:, column: }`
        # @return [void]
        def edit(start_byte:, old_end_byte:, new_end_byte:, start_point:, old_end_point:, new_end_point:)
          point_class = Java.java_classes[:Point]
          input_edit_class = Java.java_classes[:InputEdit]

          start_pt = point_class.new(start_point[:row], start_point[:column])
          old_end_pt = point_class.new(old_end_point[:row], old_end_point[:column])
          new_end_pt = point_class.new(new_end_point[:row], new_end_point[:column])

          input_edit = input_edit_class.new(
            start_byte,
            old_end_byte,
            new_end_byte,
            start_pt,
            old_end_pt,
            new_end_pt,
          )

          @impl.edit(input_edit)
        end
      end

      # Wrapper for java-tree-sitter Node
      #
      # @see https://tree-sitter.github.io/java-tree-sitter/io/github/treesitter/jtreesitter/Node.html
      class Node
        attr_reader :impl

        # @api private
        def initialize(impl)
          @impl = impl
        end

        # Get the type of this node
        #
        # @return [String] the node type
        def type
          @impl.type
        end

        # Get the number of children
        #
        # @return [Integer] child count
        def child_count
          @impl.childCount
        end

        # Get a child by index
        #
        # @param index [Integer] the child index
        # @return [Node] the child node
        def child(index)
          Node.new(@impl.child(index))
        end

        # Iterate over children
        #
        # @yield [Node] each child node
        # @return [void]
        def each
          return enum_for(:each) unless block_given?
          child_count.times do |i|
            yield child(i)
          end
        end

        # Get the start byte position
        #
        # @return [Integer] start byte
        def start_byte
          @impl.startByte
        end

        # Get the end byte position
        #
        # @return [Integer] end byte
        def end_byte
          @impl.endByte
        end

        # Get the start point (row, column)
        #
        # @return [Hash] with :row and :column keys
        def start_point
          pt = @impl.startPoint
          {row: pt.row, column: pt.column}
        end

        # Get the end point (row, column)
        #
        # @return [Hash] with :row and :column keys
        def end_point
          pt = @impl.endPoint
          {row: pt.row, column: pt.column}
        end

        # Check if this node has an error
        #
        # @return [Boolean] true if the node or any descendant has an error
        def has_error?
          @impl.hasError
        end

        # Check if this node is missing
        #
        # @return [Boolean] true if this is a MISSING node
        def missing?
          @impl.isMissing
        end

        # Get the text of this node
        #
        # @return [String] the source text
        def text
          @impl.text.to_s
        end
      end
      # :nocov:
    end
  end
end
