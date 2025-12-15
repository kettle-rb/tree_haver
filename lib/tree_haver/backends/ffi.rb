# frozen_string_literal: true

module TreeHaver
  # The load condition isn't really worth testing, so :nocov:
  # :nocov:
  begin
    require "ffi"
    FFI_AVAILABLE = true
  rescue LoadError
    FFI_AVAILABLE = false
  end
  # :nocov:

  module Backends
    # FFI-based backend for calling libtree-sitter directly
    #
    # This backend uses Ruby FFI (JNR-FFI on JRuby) to call the native Tree-sitter
    # C library without requiring MRI C extensions. This makes it compatible with
    # JRuby, TruffleRuby, and other Ruby implementations that support FFI.
    #
    # The FFI backend currently supports:
    # - Parsing source code
    # - AST node traversal
    # - Accessing node types and children
    #
    # Not yet supported:
    # - Query API (Tree-sitter queries/patterns)
    #
    # @note Requires the `ffi` gem and libtree-sitter shared library to be installed
    # @see https://github.com/ffi/ffi Ruby FFI
    # @see https://tree-sitter.github.io/tree-sitter/ Tree-sitter
    module FFI
      # Native FFI bindings to libtree-sitter
      #
      # This module handles loading the Tree-sitter runtime library and defining
      # FFI function attachments for the core Tree-sitter API.
      #
      # @api private
      module Native
        if FFI_AVAILABLE && defined?(::FFI)
          extend ::FFI::Library

          # FFI struct representation of TSNode
          #
          # Mirrors the C struct layout used by Tree-sitter. TSNode is passed
          # by value in the Tree-sitter C API.
          #
          # @api private
          class TSNode < ::FFI::Struct
            layout :context,
              [:uint32, 4],
              :id,
              :pointer,
              :tree,
              :pointer
          end

          typedef TSNode.by_value, :ts_node

          class << self
            # Get list of candidate library names for loading libtree-sitter
            #
            # The list is built dynamically to respect environment variables set at runtime.
            # If TREE_SITTER_RUNTIME_LIB is set, it is tried first.
            #
            # @note TREE_SITTER_LIB is intentionally NOT supported
            # @return [Array<String>] list of library names to try
            # @example
            #   Native.lib_candidates
            #   # => ["tree-sitter", "libtree-sitter.so.0", "libtree-sitter.so", ...]
            def lib_candidates
              [
                ENV["TREE_SITTER_RUNTIME_LIB"],
                "tree-sitter",
                "libtree-sitter.so.0",
                "libtree-sitter.so",
                "libtree-sitter.dylib",
                "libtree-sitter.dll",
              ].compact
            end

            # Load the Tree-sitter runtime library
            #
            # Tries each candidate library name in order until one succeeds.
            # After loading, attaches FFI function definitions for the Tree-sitter API.
            #
            # @raise [TreeHaver::NotAvailable] if no library can be loaded
            # @return [void]
            # @example
            #   TreeHaver::Backends::FFI::Native.try_load!
            def try_load!
              return if @loaded # rubocop:disable ThreadSafety/ClassInstanceVariable
              last_error = nil
              candidates = lib_candidates
              candidates.each do |name|
                ffi_lib(name)
                @loaded = true # rubocop:disable ThreadSafety/ClassInstanceVariable
                break
              rescue ::FFI::NotFoundError, LoadError => e
                last_error = e
              end
              unless @loaded # rubocop:disable ThreadSafety/ClassInstanceVariable
                # :nocov:
                # This failure path cannot be tested in a shared test suite because:
                # 1. Once FFI loads a library via ffi_lib, it cannot be unloaded
                # 2. Other tests may load the library first (test order is randomized)
                # 3. The @loaded flag can be reset, but ffi_lib state persists
                # ENV precedence is tested implicitly by parsing tests that work when
                # TREE_SITTER_RUNTIME_LIB is set correctly in the environment.
                tried = candidates.join(", ")
                env_hint = ENV["TREE_SITTER_RUNTIME_LIB"] ? " TREE_SITTER_RUNTIME_LIB=#{ENV["TREE_SITTER_RUNTIME_LIB"]}." : ""
                msg = if last_error
                  "Could not load libtree-sitter (tried: #{tried}).#{env_hint} #{last_error.class}: #{last_error.message}"
                else
                  "Could not load libtree-sitter (tried: #{tried}).#{env_hint}"
                end
                raise TreeHaver::NotAvailable, msg
                # :nocov:
              end

              # Attach functions after lib is selected
              attach_function(:ts_parser_new, [], :pointer)
              attach_function(:ts_parser_delete, [:pointer], :void)
              attach_function(:ts_parser_set_language, [:pointer, :pointer], :bool)
              attach_function(:ts_parser_parse_string, [:pointer, :pointer, :string, :uint32], :pointer)

              attach_function(:ts_tree_delete, [:pointer], :void)
              attach_function(:ts_tree_root_node, [:pointer], :ts_node)

              attach_function(:ts_node_type, [:ts_node], :string)
              attach_function(:ts_node_child_count, [:ts_node], :uint32)
              attach_function(:ts_node_child, [:ts_node, :uint32], :ts_node)
            end

            def loaded?
              !!@loaded
            end
          end
        else
          # :nocov:
          # Fallback stubs when FFI gem is not installed.
          # These paths cannot be tested in a test suite where FFI is a dependency,
          # since the gem is always available. They provide graceful degradation
          # for environments where FFI cannot be installed.
          class << self
            def try_load!
              raise TreeHaver::NotAvailable, "FFI not available"
            end

            def loaded?
              false
            end
          end
          # :nocov:
        end
      end

      class << self
        # Check if the FFI backend is available
        #
        # Returns true if the `ffi` gem is present. The actual runtime library
        # (libtree-sitter) is loaded lazily when needed.
        #
        # @return [Boolean] true if FFI gem is available
        # @example
        #   if TreeHaver::Backends::FFI.available?
        #     puts "FFI backend is ready"
        #   end
        def available?
          return false unless FFI_AVAILABLE && defined?(::FFI)
          # We report available when ffi is present; loading lib happens lazily
          true
        end

        # Get capabilities supported by this backend
        #
        # @return [Hash{Symbol => Object}] capability map
        # @example
        #   TreeHaver::Backends::FFI.capabilities
        #   # => { backend: :ffi, parse: true, query: false, bytes_field: true }
        def capabilities
          return {} unless available?
          {
            backend: :ffi,
            parse: true,
            query: false,
            bytes_field: true,
          }
        end
      end

      # Represents a Tree-sitter language loaded via FFI
      #
      # Holds a pointer to a TSLanguage struct from a loaded shared library.
      class Language
        # The FFI pointer to the TSLanguage struct
        # @return [FFI::Pointer]
        attr_reader :pointer

        # @api private
        # @param ptr [FFI::Pointer] pointer to TSLanguage
        def initialize(ptr)
          @pointer = ptr
        end

        # Convert to FFI pointer for passing to native functions
        #
        # @return [FFI::Pointer]
        def to_ptr
          @pointer
        end

        # Load a language from a shared library
        #
        # The library must export a function that returns a pointer to a TSLanguage struct.
        # Symbol resolution uses this precedence (when symbol: not provided):
        # 1. ENV["TREE_SITTER_LANG_SYMBOL"]
        # 2. Guessed from filename (e.g., "libtree-sitter-toml.so" → "tree_sitter_toml")
        # 3. Default fallback ("tree_sitter_toml")
        #
        # @param path [String] absolute path to the language shared library
        # @param symbol [String, nil] explicit exported function name (highest precedence)
        # @param name [String, nil] optional logical name (accepted for compatibility, not used)
        # @return [Language] loaded language handle
        # @raise [TreeHaver::NotAvailable] if FFI not available or library cannot be loaded
        # @example
        #   lang = TreeHaver::Backends::FFI::Language.from_library(
        #     "/usr/local/lib/libtree-sitter-toml.so",
        #     symbol: "tree_sitter_toml"
        #   )
        class << self
          def from_library(path, symbol: nil, name: nil)
            raise TreeHaver::NotAvailable, "FFI not available" unless Backends::FFI.available?
            begin
              dl = ::FFI::DynamicLibrary.open(path, ::FFI::DynamicLibrary::RTLD_LAZY)
            rescue LoadError => e
              raise TreeHaver::NotAvailable, "Could not open language library at #{path}: #{e.message}"
            end

            requested = symbol || ENV["TREE_SITTER_LANG_SYMBOL"]
            base = File.basename(path)
            guessed_lang = base.sub(/^libtree[-_]sitter[-_]/, "").sub(/\.(so(\.\d+)?)|\.dylib|\.dll\z/, "")
            # If an override was provided (arg or ENV), treat it as strict and do not fall back.
            # Only when no override is provided do we attempt guessed and default candidates.
            candidates = if requested && !requested.to_s.empty?
              [requested]
            else
              [(guessed_lang.empty? ? nil : "tree_sitter_#{guessed_lang}"), "tree_sitter_toml"].compact
            end

            func = nil
            last_err = nil
            candidates.each do |name|
              addr = dl.find_function(name)
              func = ::FFI::Function.new(:pointer, [], addr)
              break
            rescue StandardError => e
              last_err = e
            end
            unless func
              env_used = []
              env_used << "TREE_SITTER_LANG_SYMBOL=#{ENV["TREE_SITTER_LANG_SYMBOL"]}" if ENV["TREE_SITTER_LANG_SYMBOL"]
              detail = env_used.empty? ? "" : " Env overrides: #{env_used.join(", ")}."
              raise TreeHaver::NotAvailable, "Could not resolve language symbol in #{path} (tried: #{candidates.join(", ")}).#{detail} #{last_err&.message}"
            end

            # Only ensure the core lib is loaded when we actually need to interact with it
            # (e.g., during parsing). Creating the Language handle does not require core to be loaded.
            ptr = func.call
            raise TreeHaver::NotAvailable, "Language factory returned NULL for #{path}" if ptr.null?
            new(ptr)
          end

          # Backward-compatible alias
          alias_method :from_path, :from_library
        end
      end

      # FFI-based Tree-sitter parser
      #
      # Wraps a TSParser pointer and manages its lifecycle with a finalizer.
      class Parser
        # Create a new parser instance
        #
        # @raise [TreeHaver::NotAvailable] if FFI not available or parser creation fails
        def initialize
          raise TreeHaver::NotAvailable, "FFI not available" unless Backends::FFI.available?

          Native.try_load!
          @parser = Native.ts_parser_new
          raise TreeHaver::NotAvailable, "Failed to create ts_parser" if @parser.null?

          ObjectSpace.define_finalizer(self, self.class.finalizer(@parser))
        end

        class << self
          # @api private
          # @param ptr [FFI::Pointer] pointer to TSParser
          # @return [Proc] finalizer that deletes the parser
          def finalizer(ptr)
            proc {
              begin
                Native.ts_parser_delete(ptr)
              rescue StandardError
                nil
              end
            }
          end
        end

        # Set the language for this parser
        #
        # @param lang [Language] the language to use for parsing
        # @return [Language] the language that was set
        # @raise [TreeHaver::NotAvailable] if setting the language fails
        def language=(lang)
          ok = Native.ts_parser_set_language(@parser, lang.to_ptr)
          raise TreeHaver::NotAvailable, "Failed to set language on parser" unless ok

          lang
        end

        # Parse source code into a syntax tree
        #
        # @param source [String] the source code to parse (should be UTF-8)
        # @return [Tree] the parsed syntax tree
        # @raise [TreeHaver::NotAvailable] if parsing fails
        def parse(source)
          src = String(source)
          tree_ptr = Native.ts_parser_parse_string(@parser, ::FFI::Pointer::NULL, src, src.bytesize)
          raise TreeHaver::NotAvailable, "Parse returned NULL" if tree_ptr.null?

          Tree.new(tree_ptr)
        end
      end

      # FFI-based Tree-sitter tree
      #
      # Wraps a TSTree pointer and manages its lifecycle with a finalizer.
      class Tree
        # @api private
        # @param ptr [FFI::Pointer] pointer to TSTree
        def initialize(ptr)
          @ptr = ptr
          ObjectSpace.define_finalizer(self, self.class.finalizer(@ptr))
        end

        # @api private
        # @param ptr [FFI::Pointer] pointer to TSTree
        class << self
          # @return [Proc] finalizer that deletes the tree
          def finalizer(ptr)
            proc {
              begin
                Native.ts_tree_delete(ptr)
              rescue StandardError
                nil
              end
            }
          end
        end

        # Get the root node of the syntax tree
        #
        # @return [Node] the root node
        def root_node
          node_val = Native.ts_tree_root_node(@ptr)
          Node.new(node_val)
        end
      end

      # FFI-based Tree-sitter node
      #
      # Wraps a TSNode by-value struct. TSNode is passed by value in the
      # Tree-sitter C API, so we store the struct value directly.
      class Node
        # @api private
        # @param ts_node_value [Native::TSNode] the TSNode struct (by value)
        def initialize(ts_node_value)
          # Store by-value struct (FFI will copy); methods pass it back by value
          @val = ts_node_value
        end

        # Get the type name of this node
        #
        # @return [String] the node type (e.g., "document", "table", "pair")
        def type
          Native.ts_node_type(@val)
        end

        # Iterate over child nodes
        #
        # @yieldparam child [Node] each child node
        # @return [Enumerator, nil] an enumerator if no block given, nil otherwise
        def each
          return enum_for(:each) unless block_given?

          count = Native.ts_node_child_count(@val)
          i = 0
          while i < count
            child = Native.ts_node_child(@val, i)
            yield Node.new(child)
            i += 1
          end
          nil
        end
      end
    end
  end
end
