# frozen_string_literal: true

module TreeHaver
  # Thread-safe language registrations and cache for loaded Language handles.
  #
  # Responsibilities:
  # - Registrations: name(Symbol) => { path: String, symbol: String|nil }
  # - Cache: key(Array[path, symbol, name]) => backend-specific Language
  module LanguageRegistry
    @mutex = Mutex.new
    @cache = {}
    @registrations = {}

    module_function

    # Register a language helper by name.
    # @param name [Symbol, String]
    # @param path [String]
    # @param symbol [String, nil]
    # @return [void]
    def register(name, path:, symbol: nil)
      key = name.to_sym
      @mutex.synchronize do
        @registrations[key] = { path: path, symbol: symbol }
      end
      nil
    end

    # Unregister a previously registered language helper.
    # @param name [Symbol, String]
    # @return [void]
    def unregister(name)
      key = name.to_sym
      @mutex.synchronize do
        @registrations.delete(key)
      end
      nil
    end

    # Fetch a registration entry.
    # @param name [Symbol, String]
    # @return [Hash, nil]
    def registered(name)
      @mutex.synchronize { @registrations[name.to_sym] }
    end

    # Clear all registrations (intended for tests)
    # @return [void]
    def clear_registrations!
      @mutex.synchronize { @registrations.clear }
      nil
    end

    # Fetch a cached language by key or compute and store it
    # @param key [Array]
    # @yieldreturn computed language handle
    def fetch(key)
      @mutex.synchronize do
        return @cache[key] if @cache.key?(key)
        value = yield
        @cache[key] = value
      end
    end

    # Clear language cache
    def clear_cache!
      @mutex.synchronize { @cache.clear }
      nil
    end

    # Clear everything (registrations + cache)
    def clear_all!
      @mutex.synchronize do
        @registrations.clear
        @cache.clear
      end
      nil
    end
  end
end
