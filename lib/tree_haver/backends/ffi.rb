# frozen_string_literal: true

begin
  require "ffi"
  FFI_AVAILABLE = true
rescue LoadError
  FFI_AVAILABLE = false
end

module TreeHaver
  module Backends
    # JRuby-/FFI-oriented backend. Calls native libtree-sitter via Ruby-FFI
    # (JNR-FFI on JRuby). Does not require MRI C extensions.
    module FFI
      # Native bindings loader
      module Native
        if FFI_AVAILABLE && defined?(::FFI)
          extend ::FFI::Library

        # Build list of core runtime candidates at call-time so ENV stubbing in tests
        # (and late configuration) is reflected in diagnostics.
        # NOTE: We intentionally do NOT support TREE_SITTER_LIB; only TREE_SITTER_RUNTIME_LIB
        def self.lib_candidates
          [
            ENV["TREE_SITTER_RUNTIME_LIB"],
            "tree-sitter",
            "libtree-sitter.so.0",
            "libtree-sitter.so",
            "libtree-sitter.dylib",
            "libtree-sitter.dll",
          ].compact
        end

        class TSNode < ::FFI::Struct
          layout :context, [:uint32, 4],
                 :id,      :pointer,
                 :tree,    :pointer
        end

        typedef TSNode.by_value, :ts_node

          def self.try_load!
            return if @loaded
            last_error = nil
            candidates = lib_candidates
            candidates.each do |name|
              begin
                ffi_lib name
                @loaded = true
                break
              rescue ::FFI::NotFoundError, LoadError => e
                last_error = e
              end
            end
            unless @loaded
              tried = candidates.join(", ")
              env_hint = ENV["TREE_SITTER_RUNTIME_LIB"] ? " TREE_SITTER_RUNTIME_LIB=#{ENV["TREE_SITTER_RUNTIME_LIB"]}." : ""
              msg = if last_error
                "Could not load libtree-sitter (tried: #{tried}).#{env_hint} #{last_error.class}: #{last_error.message}"
              else
                "Could not load libtree-sitter (tried: #{tried}).#{env_hint}"
              end
              raise TreeHaver::NotAvailable, msg
            end

            # Attach functions after lib is selected
            attach_function :ts_parser_new, [], :pointer
            attach_function :ts_parser_delete, [:pointer], :void
            attach_function :ts_parser_set_language, [:pointer, :pointer], :bool
            attach_function :ts_parser_parse_string, [:pointer, :pointer, :string, :uint32], :pointer

            attach_function :ts_tree_delete, [:pointer], :void
            attach_function :ts_tree_root_node, [:pointer], :ts_node

            attach_function :ts_node_type, [:ts_node], :string
            attach_function :ts_node_child_count, [:ts_node], :uint32
            attach_function :ts_node_child, [:ts_node, :uint32], :ts_node
          end

          def self.loaded?
            !!@loaded
          end
        else
          # Fallback stubs when FFI is not present; callers should have checked availability
          def self.try_load!
            raise TreeHaver::NotAvailable, "FFI not available"
          end

          def self.loaded?
            false
          end
        end
      end

      def self.available?
        return false unless FFI_AVAILABLE && defined?(::FFI)
        # We report available when ffi is present; loading lib happens lazily
        true
      end

      def self.capabilities
        return {} unless available?
        {
          backend: :ffi,
          parse: true,
          query: false,
          bytes_field: true,
        }
      end

      class Language
        # pointer to TSLanguage
        attr_reader :pointer

        def initialize(ptr)
          @pointer = ptr
        end

        def to_ptr
          @pointer
        end

        # Load a language from a shared library that exports a function returning TSLanguage*
        # Options:
        #   symbol: explicit exported function name to use (highest precedence)
        #   name:   an optional logical name (not used here, but accepted for facade compatibility)
        # Symbol resolution precedence (when symbol: not given):
        #   ENV["TREE_SITTER_LANG_SYMBOL"] → ENV["TREE_HAVER_LANG_SYMBOL"] → guessed → default("tree_sitter_toml")
        def self.from_library(path, symbol: nil, name: nil)
          raise TreeHaver::NotAvailable, "FFI not available" unless Backends::FFI.available?
          begin
            dl = ::FFI::DynamicLibrary.open(path, ::FFI::DynamicLibrary::RTLD_LAZY)
          rescue LoadError => e
            raise TreeHaver::NotAvailable, "Could not open language library at #{path}: #{e.message}"
          end

          requested = symbol || ENV["TREE_SITTER_LANG_SYMBOL"] || ENV["TREE_HAVER_LANG_SYMBOL"]
          base = File.basename(path)
          guessed_lang = base.sub(/^libtree[-_]sitter[-_]/, "").sub(/\.(so(\.\d+)?)|\.dylib|\.dll\z/, "")
          # If an override was provided (arg or ENV), treat it as strict and do not fall back.
          # Only when no override is provided do we attempt guessed and default candidates.
          candidates = if requested && !requested.to_s.empty?
            [requested]
          else
            [ (guessed_lang.empty? ? nil : "tree_sitter_#{guessed_lang}"), "tree_sitter_toml" ].compact
          end

          func = nil
          last_err = nil
          candidates.each do |name|
            begin
              addr = dl.find_function(name)
              func = ::FFI::Function.new(:pointer, [], addr)
              break
            rescue StandardError => e
              last_err = e
            end
          end
          unless func
            env_used = []
            env_used << "TREE_SITTER_LANG_SYMBOL=#{ENV["TREE_SITTER_LANG_SYMBOL"]}" if ENV["TREE_SITTER_LANG_SYMBOL"]
            env_used << "TREE_HAVER_LANG_SYMBOL=#{ENV["TREE_HAVER_LANG_SYMBOL"]}" if ENV["TREE_HAVER_LANG_SYMBOL"]
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
        class << self
          alias from_path from_library
        end
      end

      class Parser
        def initialize
          raise TreeHaver::NotAvailable, "FFI not available" unless Backends::FFI.available?
          Native.try_load!
          @parser = Native.ts_parser_new
          raise TreeHaver::NotAvailable, "Failed to create ts_parser" if @parser.null?
          ObjectSpace.define_finalizer(self, self.class.finalizer(@parser))
        end

        def self.finalizer(ptr)
          proc { Native.ts_parser_delete(ptr) rescue nil }
        end

        def language=(lang)
          ok = Native.ts_parser_set_language(@parser, lang.to_ptr)
          raise TreeHaver::NotAvailable, "Failed to set language on parser" unless ok
          lang
        end

        def parse(source)
          src = String(source)
          tree_ptr = Native.ts_parser_parse_string(@parser, ::FFI::Pointer::NULL, src, src.bytesize)
          raise TreeHaver::NotAvailable, "Parse returned NULL" if tree_ptr.null?
          Tree.new(tree_ptr)
        end
      end

      class Tree
        def initialize(ptr)
          @ptr = ptr
          ObjectSpace.define_finalizer(self, self.class.finalizer(@ptr))
        end

        def self.finalizer(ptr)
          proc { Native.ts_tree_delete(ptr) rescue nil }
        end

        def root_node
          node_val = Native.ts_tree_root_node(@ptr)
          Node.new(node_val)
        end
      end

      class Node
        def initialize(ts_node_value)
          # Store by-value struct (FFI will copy); methods pass it back by value
          @val = ts_node_value
        end

        def type
          Native.ts_node_type(@val)
        end

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
