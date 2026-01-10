# frozen_string_literal: true

module TreeHaver
  # Represents a tree-sitter parser instance
  #
  # A Parser is used to parse source code into a syntax tree. You must
  # set a language before parsing.
  #
  # == Wrapping/Unwrapping Responsibility
  #
  # TreeHaver::Parser is responsible for ALL object wrapping and unwrapping:
  #
  # **Language objects:**
  # - Unwraps Language wrappers before passing to backend.language=
  # - MRI backend receives ::TreeSitter::Language
  # - Rust backend receives String (language name)
  # - FFI backend receives wrapped Language (needs to_ptr)
  #
  # **Tree objects:**
  # - parse() receives raw source, backend returns raw tree, Parser wraps it
  # - parse_string() unwraps old_tree before passing to backend, wraps returned tree
  # - Backends always work with raw backend trees, never TreeHaver::Tree
  #
  # **Node objects:**
  # - Backends return raw nodes, TreeHaver::Tree and TreeHaver::Node wrap them
  #
  # This design ensures:
  # - Principle of Least Surprise: wrapping happens at boundaries, consistently
  # - Backends are simple: they don't need to know about TreeHaver wrappers
  # - Single Responsibility: wrapping logic is only in TreeHaver::Parser
  #
  # @example Basic parsing
  #   parser = TreeHaver::Parser.new
  #   parser.language = TreeHaver::Language.toml
  #   tree = parser.parse("[package]\nname = \"foo\"")
  class Parser
    # Create a new parser instance
    #
    # @param backend [Symbol, String, nil] optional backend to use (overrides context/global)
    # @raise [NotAvailable] if no backend is available or requested backend is unavailable
    # @example Default (uses context/global)
    #   parser = TreeHaver::Parser.new
    # @example Explicit backend
    #   parser = TreeHaver::Parser.new(backend: :ffi)
    def initialize(backend: nil)
      # Convert string backend names to symbols for consistency
      backend = backend.to_sym if backend.is_a?(String)

      mod = TreeHaver.resolve_backend_module(backend)

      if mod.nil?
        if backend
          raise NotAvailable, "Requested backend #{backend.inspect} is not available"
        else
          raise NotAvailable, "No TreeHaver backend is available"
        end
      end

      # Try to create the parser, with fallback to Citrus if tree-sitter fails
      # This enables auto-fallback when tree-sitter runtime isn't available
      begin
        @impl = mod::Parser.new
        @explicit_backend = backend  # Remember for introspection (always a Symbol or nil)
      rescue NoMethodError, LoadError => e
        # Note: FFI::NotFoundError inherits from LoadError, so it's caught here too
        handle_parser_creation_failure(e, backend)
      end
    end

    # Handle parser creation failure with optional Citrus fallback
    #
    # @param error [Exception] the error that caused parser creation to fail
    # @param backend [Symbol, nil] the requested backend
    # @raise [NotAvailable] if no fallback is available
    # @api private
    def handle_parser_creation_failure(error, backend)
      # Tree-sitter backend failed (likely missing runtime library)
      # Try Citrus as fallback if we weren't explicitly asked for a specific backend
      if backend.nil? || backend == :auto
        if Backends::Citrus.available?
          @impl = Backends::Citrus::Parser.new
          @explicit_backend = :citrus
        else
          # No fallback available, re-raise original error
          raise NotAvailable, "Tree-sitter backend failed: #{error.message}. " \
            "Citrus fallback not available. Install tree-sitter runtime or citrus gem."
        end
      else
        # Explicit backend was requested, don't fallback
        raise error
      end
    end

    # Get the backend this parser is using (for introspection)
    #
    # Returns the actual backend in use, resolving :auto to the concrete backend.
    #
    # @return [Symbol] the backend name (:mri, :rust, :ffi, :java, or :citrus)
    def backend
      if @explicit_backend && @explicit_backend != :auto
        @explicit_backend
      else
        # Determine actual backend from the implementation class
        case @impl.class.name
        when /MRI/
          :mri
        when /Rust/
          :rust
        when /FFI/
          :ffi
        when /Java/
          :java
        when /Citrus/
          :citrus
        else
          # Fallback to effective_backend if we can't determine from class name
          TreeHaver.effective_backend
        end
      end
    end

    # Set the language grammar for this parser
    #
    # @param lang [Language] the language to use for parsing
    # @return [Language] the language that was set
    # @example
    #   parser.language = TreeHaver::Language.from_library("/path/to/grammar.so")
    def language=(lang)
      # Check if this is a Citrus language - if so, we need a Citrus parser
      # This enables automatic backend switching when tree-sitter fails and
      # falls back to Citrus
      if lang.is_a?(Backends::Citrus::Language)
        unless @impl.is_a?(Backends::Citrus::Parser)
          # Switch to Citrus parser to match the Citrus language
          @impl = Backends::Citrus::Parser.new
          @explicit_backend = :citrus
        end
      end

      # Unwrap the language before passing to backend
      # Backends receive raw language objects, never TreeHaver wrappers
      inner_lang = unwrap_language(lang)
      @impl.language = inner_lang
      # Return the original (possibly wrapped) language for consistency
      lang # rubocop:disable Lint/Void (intentional return value)
    end

    # Parse source code into a syntax tree
    #
    # @param source [String] the source code to parse (should be UTF-8)
    # @return [Tree] the parsed syntax tree
    # @example
    #   tree = parser.parse("x = 1")
    #   puts tree.root_node.type
    def parse(source)
      tree_impl = @impl.parse(source)
      # Wrap backend tree with source so Node#text works
      Tree.new(tree_impl, source: source)
    end

    # Parse source code into a syntax tree (with optional incremental parsing)
    #
    # This method provides API compatibility with ruby_tree_sitter which uses
    # `parse_string(old_tree, source)`.
    #
    # == Incremental Parsing
    #
    # tree-sitter supports **incremental parsing** where you can pass a previously
    # parsed tree along with edit information to efficiently re-parse only the
    # changed portions of source code. This is a major performance optimization
    # for editors and IDEs that need to re-parse on every keystroke.
    #
    # The workflow for incremental parsing is:
    # 1. Parse the initial source: `tree = parser.parse_string(nil, source)`
    # 2. User edits the source (e.g., inserts a character)
    # 3. Call `tree.edit(...)` to update the tree's position data
    # 4. Re-parse with the old tree: `new_tree = parser.parse_string(tree, new_source)`
    # 5. tree-sitter reuses unchanged nodes, only re-parsing affected regions
    #
    # TreeHaver passes through to the underlying backend if it supports incremental
    # parsing (MRI and Rust backends do). Check `TreeHaver.capabilities[:incremental]`
    # to see if the current backend supports it.
    #
    # @param old_tree [Tree, nil] previously parsed tree for incremental parsing, or nil for fresh parse
    # @param source [String] the source code to parse (should be UTF-8)
    # @return [Tree] the parsed syntax tree
    # @see https://tree-sitter.github.io/tree-sitter/using-parsers#editing tree-sitter incremental parsing docs
    # @see Tree#edit For marking edits before incremental re-parsing
    # @example First parse (no old tree)
    #   tree = parser.parse_string(nil, "x = 1")
    # @example Incremental parse
    #   tree.edit(start_byte: 4, old_end_byte: 5, new_end_byte: 6, ...)
    #   new_tree = parser.parse_string(tree, "x = 42")
    def parse_string(old_tree, source)
      # Pass through to backend if it supports incremental parsing
      if old_tree && @impl.respond_to?(:parse_string)
        # Extract the underlying implementation from our Tree wrapper
        old_impl = if old_tree.respond_to?(:inner_tree)
          old_tree.inner_tree
        elsif old_tree.respond_to?(:instance_variable_get)
          # Fallback for compatibility
          old_tree.instance_variable_get(:@inner_tree) || old_tree.instance_variable_get(:@impl) || old_tree
        else
          old_tree
        end
        tree_impl = @impl.parse_string(old_impl, source)
        # Wrap backend tree with source so Node#text works
        Tree.new(tree_impl, source: source)
      elsif @impl.respond_to?(:parse_string)
        tree_impl = @impl.parse_string(nil, source)
        # Wrap backend tree with source so Node#text works
        Tree.new(tree_impl, source: source)
      else
        # Fallback for backends that don't support parse_string
        parse(source)
      end
    end

    private

    # Unwrap a language object to extract the raw backend language
    #
    # This method is smart about backend compatibility:
    # 1. If language has a backend attribute, checks if it matches current backend
    # 2. If mismatch detected, attempts to reload language for correct backend
    # 3. If reload successful, uses new language; otherwise continues with original
    # 4. Unwraps the language wrapper to get raw backend object
    #
    # @param lang [Object] wrapped or raw language object
    # @return [Object] raw backend language object appropriate for current backend
    # @api private
    def unwrap_language(lang)
      # Check if this is a TreeHaver language wrapper with backend info
      if lang.respond_to?(:backend)
        # Verify backend compatibility FIRST
        # This prevents passing languages from wrong backends to native code
        # Exception: :auto backend is permissive - accepts any language
        current_backend = backend

        if lang.backend != current_backend && current_backend != :auto
          # Backend mismatch! Try to reload for correct backend
          reloaded = try_reload_language_for_backend(lang, current_backend)
          if reloaded
            lang = reloaded
          else
            # Couldn't reload - this is an error
            raise TreeHaver::Error,
              "Language backend mismatch: language is for #{lang.backend}, parser is #{current_backend}. " \
                "Cannot reload language for correct backend. " \
                "Create a new language with TreeHaver::Language.from_library when backend is #{current_backend}."
          end
        end

        # Get the current parser's language (if set)
        current_lang = @impl.respond_to?(:language) ? @impl.language : nil

        # Language mismatch detected! The parser might have a different language set
        # Compare the actual language objects using Comparable
        if current_lang && lang != current_lang
          # Different language being set (e.g., switching from TOML to JSON)
          # This is fine, just informational
        end
      end

      # Unwrap based on backend type
      # All TreeHaver Language wrappers have the backend attribute
      unless lang.respond_to?(:backend)
        # This shouldn't happen - all our wrappers have backend attribute
        # If we get here, it's likely a raw backend object that was passed directly
        raise TreeHaver::Error,
          "Expected TreeHaver Language wrapper with backend attribute, got #{lang.class}. " \
            "Use TreeHaver::Language.from_library to create language objects."
      end

      case lang.backend
      when :mri
        return lang.to_language if lang.respond_to?(:to_language)
        return lang.inner_language if lang.respond_to?(:inner_language)
      when :rust
        return lang.name if lang.respond_to?(:name)
      when :ffi
        return lang  # FFI needs wrapper for to_ptr
      when :java
        return lang.impl if lang.respond_to?(:impl)
      when :citrus
        return lang.grammar_module if lang.respond_to?(:grammar_module)
      when :prism
        return lang  # Prism backend expects the Language wrapper
      when :psych
        return lang  # Psych backend expects the Language wrapper
      when :commonmarker
        return lang  # Commonmarker backend expects the Language wrapper
      when :markly
        return lang  # Markly backend expects the Language wrapper
      else
        # Unknown backend (e.g., test backend)
        # Try generic unwrapping methods for flexibility in testing
        return lang.to_language if lang.respond_to?(:to_language)
        return lang.inner_language if lang.respond_to?(:inner_language)
        return lang.impl if lang.respond_to?(:impl)
        return lang.grammar_module if lang.respond_to?(:grammar_module)
        return lang.name if lang.respond_to?(:name)

        # If nothing works, pass through as-is
        # This allows test languages to be passed directly
        return lang
      end

      # Shouldn't reach here, but just in case
      lang
    end

    # Try to reload a language for the current backend
    #
    # This handles the case where a language was loaded for one backend,
    # but is now being used with a different backend (e.g., after backend switch).
    #
    # @param lang [Object] language object with metadata
    # @param target_backend [Symbol] backend to reload for
    # @return [Object, nil] reloaded language or nil if reload not possible
    # @api private
    def try_reload_language_for_backend(lang, target_backend)
      # Can't reload without path information
      return unless lang.respond_to?(:path) || lang.respond_to?(:grammar_module)

      # For tree-sitter backends, reload from path
      if lang.respond_to?(:path) && lang.path
        begin
          # Use Language.from_library which respects current backend
          return Language.from_library(
            lang.path,
            symbol: lang.respond_to?(:symbol) ? lang.symbol : nil,
            name: lang.respond_to?(:name) ? lang.name : nil,
          )
        rescue => e
          # Reload failed, continue with original
          warn("TreeHaver: Failed to reload language for backend #{target_backend}: #{e.message}") if $VERBOSE
          return
        end
      end

      # For Citrus, can't really reload as it's just a module reference
      nil
    end
  end
end
