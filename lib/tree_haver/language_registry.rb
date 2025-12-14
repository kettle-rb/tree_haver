# frozen_string_literal: true

module TreeHaver
  # Thread-safe language registrations and cache for loaded Language handles
  #
  # The LanguageRegistry provides two main functions:
  # 1. **Registrations**: Store mappings from language names to shared library paths
  # 2. **Cache**: Memoize loaded Language objects to avoid repeated dlopen calls
  #
  # All operations are thread-safe and protected by a mutex.
  #
  # @example Register and cache a language
  #   TreeHaver::LanguageRegistry.register(:toml, path: "/path/to/lib.so", symbol: "tree_sitter_toml")
  #   lang = TreeHaver::LanguageRegistry.fetch(["/path/to/lib.so", "tree_sitter_toml", "toml"]) do
  #     # This block is called only if not cached
  #     load_language_from_library(...)
  #   end
  #
  # @api private
  module LanguageRegistry
    @mutex = Mutex.new
    @cache = {}
    @registrations = {}

    module_function

    # Register a language helper by name
    #
    # Stores a mapping from a language name to its shared library path and
    # optional exported symbol name. After registration, the language can be
    # accessed via dynamic helpers on {TreeHaver::Language}.
    #
    # @param name [Symbol, String] language identifier (e.g., :toml, :json)
    # @param path [String] absolute path to the language shared library
    # @param symbol [String, nil] optional exported factory symbol (e.g., "tree_sitter_toml")
    # @return [void]
    # @example
    #   LanguageRegistry.register(:toml, path: "/usr/local/lib/libtree-sitter-toml.so")
    def register(name, path:, symbol: nil)
      key = name.to_sym
      @mutex.synchronize do
        @registrations[key] = { path: path, symbol: symbol }
      end
      nil
    end

    # Unregister a previously registered language helper
    #
    # Removes the registration entry but does not affect cached Language objects.
    #
    # @param name [Symbol, String] language identifier to unregister
    # @return [void]
    # @example
    #   LanguageRegistry.unregister(:toml)
    def unregister(name)
      key = name.to_sym
      @mutex.synchronize do
        @registrations.delete(key)
      end
      nil
    end

    # Fetch a registration entry
    #
    # Returns the stored path and symbol for a registered language name.
    #
    # @param name [Symbol, String] language identifier
    # @return [Hash{Symbol => String, nil}, nil] hash with :path and :symbol keys, or nil if not registered
    # @example
    #   entry = LanguageRegistry.registered(:toml)
    #   # => { path: "/usr/local/lib/libtree-sitter-toml.so", symbol: "tree_sitter_toml" }
    def registered(name)
      @mutex.synchronize { @registrations[name.to_sym] }
    end

    # Clear all registrations
    #
    # Removes all registered language mappings. Primarily intended for test cleanup.
    # Does not clear the language cache.
    #
    # @return [void]
    # @example
    #   LanguageRegistry.clear_registrations!
    def clear_registrations!
      @mutex.synchronize { @registrations.clear }
      nil
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

    # Clear everything (registrations and cache)
    #
    # Removes all registered languages and all cached Language objects.
    # Useful for complete teardown in tests.
    #
    # @return [void]
    # @example
    #   LanguageRegistry.clear_all!
    def clear_all!
      @mutex.synchronize do
        @registrations.clear
        @cache.clear
      end
      nil
    end
  end
end
