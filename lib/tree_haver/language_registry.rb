# frozen_string_literal: true

module TreeHaver
  # Thread-safe language registrations and cache for loaded Language handles
  #
  # The LanguageRegistry provides two main functions:
  # 1. **Registrations**: Store mappings from language names to backend-specific configurations
  # 2. **Cache**: Memoize loaded Language objects to avoid repeated dlopen calls
  #
  # The registry supports multiple backends for the same language, allowing runtime
  # switching, benchmarking, and fallback scenarios.
  #
  # Registration structure:
  # ```ruby
  # @registrations = {
  #   toml: {
  #     tree_sitter: { path: "/path/to/lib.so", symbol: "tree_sitter_toml" },
  #     citrus: { grammar_module: TomlRB::Document, gem_name: "toml-rb" }
  #   }
  # }
  # ```
  #
  # @example Register tree-sitter grammar
  # ```ruby
  #   TreeHaver::LanguageRegistry.register(:toml, :tree_sitter,
  #     path: "/path/to/lib.so", symbol: "tree_sitter_toml")
  # ```
  #
  # @example Register Citrus grammar
  # ```ruby
  #   TreeHaver::LanguageRegistry.register(:toml, :citrus,
  #     grammar_module: TomlRB::Document, gem_name: "toml-rb")
  # ```
  #
  # @api private
  module LanguageRegistry
    @mutex = Mutex.new
    @cache = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable
    @registrations = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable

    module_function

    # Register a language for a specific backend
    #
    # Stores backend-specific configuration for a language. Multiple backends
    # can be registered for the same language without conflict.
    #
    # @param name [Symbol, String] language identifier (e.g., :toml, :json)
    # @param backend_type [Symbol] backend type (:tree_sitter, :citrus, :mri, :rust, :ffi, :java)
    # @param config [Hash] backend-specific configuration
    # @option config [String] :path tree-sitter library path (for tree-sitter backends)
    # @option config [String] :symbol exported symbol name (for tree-sitter backends)
    # @option config [Module] :grammar_module Citrus grammar module (for Citrus backend)
    # @option config [String] :gem_name gem name for error messages (for Citrus backend)
    # @return [void]
    # @example Register tree-sitter grammar
    #   LanguageRegistry.register(:toml, :tree_sitter,
    #     path: "/usr/local/lib/libtree-sitter-toml.so", symbol: "tree_sitter_toml")
    # @example Register Citrus grammar
    #   LanguageRegistry.register(:toml, :citrus,
    #     grammar_module: TomlRB::Document, gem_name: "toml-rb")
    def register(name, backend_type, **config)
      key = name.to_sym
      backend_key = backend_type.to_sym

      @mutex.synchronize do
        @registrations[key] ||= {}
        @registrations[key][backend_key] = config.compact
      end
      nil
    end

    # Fetch registration entries for a language
    #
    # Returns all backend-specific configurations for a language.
    #
    # @param name [Symbol, String] language identifier
    # @param backend_type [Symbol, nil] optional backend type to filter by
    # @return [Hash{Symbol => Hash}, Hash, nil] all backends or specific backend config
    # @example Get all backends
    #   entries = LanguageRegistry.registered(:toml)
    #   # => {
    #   #   tree_sitter: { path: "/usr/local/lib/libtree-sitter-toml.so", symbol: "tree_sitter_toml" },
    #   #   citrus: { grammar_module: TomlRB::Document, gem_name: "toml-rb" }
    #   # }
    # @example Get specific backend
    #   entry = LanguageRegistry.registered(:toml, :citrus)
    #   # => { grammar_module: TomlRB::Document, gem_name: "toml-rb" }
    def registered(name, backend_type = nil)
      @mutex.synchronize do
        lang_config = @registrations[name.to_sym]
        return unless lang_config

        if backend_type
          lang_config[backend_type.to_sym]
        else
          lang_config
        end
      end
    end

    # Fetch a cached language by key or compute and store it
    #
    # This method provides thread-safe memoization for loaded Language objects.
    # If the key exists in the cache, the cached value is returned immediately.
    # Otherwise, the block is called to compute the value, which is then cached.
    #
    # @param key [Array] cache key, typically [path, symbol, name]
    # @yieldreturn [Object] the computed language handle (called only on cache miss)
    # @return [Object] the cached or computed language handle
    # @example
    #   language = LanguageRegistry.fetch(["/path/lib.so", "symbol", "toml"]) do
    #     expensive_language_load_operation
    #   end
    def fetch(key)
      @mutex.synchronize do
        return @cache[key] if @cache.key?(key)
        value = yield
        @cache[key] = value
      end
    end

    # Clear the language cache
    #
    # Removes all cached Language objects. The next call to {fetch} for any key
    # will recompute the value. Does not clear registrations.
    #
    # @return [void]
    # @example
    #   LanguageRegistry.clear_cache!
    def clear_cache!
      @mutex.synchronize { @cache.clear }
      nil
    end
  end
end
