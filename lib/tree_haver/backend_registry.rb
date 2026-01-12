# frozen_string_literal: true

module TreeHaver
  # Registry for backend dependency tag availability checkers
  #
  # This module allows external gems (like commonmarker-merge, markly-merge, rbs-merge)
  # to register their availability checker for RSpec dependency tags without
  # TreeHaver needing to know about them directly.
  #
  # == Purpose
  #
  # When running RSpec tests with dependency tags (e.g., `:commonmarker_backend`),
  # TreeHaver needs to know if each backend is available. Rather than hardcoding
  # checks like `TreeHaver::Backends::Commonmarker.available?` (which would fail
  # if the backend module doesn't exist), the BackendRegistry provides a dynamic
  # way for backends to register their availability checkers.
  #
  # == Built-in vs External Backends
  #
  # - **Built-in backends** (MRI, Rust, FFI, Java, Prism, Psych, Citrus) register
  #   their checkers automatically when loaded from `tree_haver/backends/*.rb`
  # - **External backends** (commonmarker-merge, markly-merge, rbs-merge) register
  #   their checkers when their backend module is loaded
  #
  # == Full Tag Registration
  #
  # External gems can register complete tag support using {register_tag}:
  # - Tag name (e.g., :commonmarker_backend)
  # - Category (:backend, :gem, :parsing, :grammar)
  # - Availability checker
  # - Optional require path for lazy loading
  #
  # This enables tree_haver/rspec/dependency_tags to automatically configure
  # RSpec exclusion filters for any registered tag without hardcoded knowledge.
  #
  # == Thread Safety
  #
  # All operations are thread-safe using a Mutex for synchronization.
  # Results are cached after first check for performance.
  #
  # @example Registering a backend availability checker (simple form)
  #   # In commonmarker-merge/lib/commonmarker/merge/backend.rb
  #   TreeHaver::BackendRegistry.register_availability_checker(:commonmarker) do
  #     available?
  #   end
  #
  # @example Registering a full tag with require path (preferred for external gems)
  #   TreeHaver::BackendRegistry.register_tag(
  #     :commonmarker_backend,
  #     category: :backend,
  #     backend_name: :commonmarker,
  #     require_path: "commonmarker/merge"
  #   ) { Commonmarker::Merge::Backend.available? }
  #
  # @example Checking backend availability
  #   TreeHaver::BackendRegistry.available?(:commonmarker)  # => true/false
  #   TreeHaver::BackendRegistry.available?(:markly)        # => true/false
  #   TreeHaver::BackendRegistry.available?(:rbs)           # => true/false
  #
  # @example Getting all registered tags
  #   TreeHaver::BackendRegistry.registered_tags # => [:commonmarker_backend, :markly_backend, ...]
  #   TreeHaver::BackendRegistry.tags_by_category(:backend) # => [...]
  #
  # @see TreeHaver::RSpec::DependencyTags Uses BackendRegistry for dynamic backend detection
  # @api public
  module BackendRegistry
    @mutex = Mutex.new
    @availability_checkers = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable
    @availability_cache = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable
    @tag_registry = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable

    # Tag categories for organizing dependency tags
    # @api private
    CATEGORIES = %i[backend gem parsing grammar engine other].freeze

    module_function

    # Register a full dependency tag with all metadata
    #
    # This is the preferred method for external gems to register their availability
    # with complete tag support. It registers both the availability checker and
    # the tag metadata needed for RSpec configuration.
    #
    # When a tag is registered, this also dynamically defines a `*_available?` method
    # on `TreeHaver::RSpec::DependencyTags` if it doesn't already exist.
    #
    # @param tag_name [Symbol] the RSpec tag name (e.g., :commonmarker_backend)
    # @param category [Symbol] one of :backend, :gem, :parsing, :grammar, :engine, :other
    # @param backend_name [Symbol, nil] the backend name for availability checks (defaults to tag without suffix)
    # @param require_path [String, nil] optional require path to load before checking availability
    # @param checker [#call, nil] a callable that returns true if available
    # @yield Block form of checker (alternative to passing a callable)
    # @yieldreturn [Boolean] true if the tag's dependency is available
    # @return [void]
    #
    # @example Register a backend tag with require path
    #   TreeHaver::BackendRegistry.register_tag(
    #     :commonmarker_backend,
    #     category: :backend,
    #     require_path: "commonmarker/merge"
    #   ) { Commonmarker::Merge::Backend.available? }
    #
    # @example Register a gem tag
    #   TreeHaver::BackendRegistry.register_tag(
    #     :toml_gem,
    #     category: :gem,
    #     require_path: "toml"
    #   ) { defined?(TOML) }
    def register_tag(tag_name, category:, backend_name: nil, require_path: nil, checker: nil, &block)
      callable = checker || block
      raise ArgumentError, "Must provide a checker callable or block" unless callable
      raise ArgumentError, "Checker must respond to #call" unless callable.respond_to?(:call)
      raise ArgumentError, "Invalid category: #{category}" unless CATEGORIES.include?(category)

      tag_sym = tag_name.to_sym
      # Derive backend_name from tag_name if not provided (e.g., :commonmarker_backend -> :commonmarker)
      derived_backend = backend_name || tag_sym.to_s.sub(/_backend$/, "").to_sym

      @mutex.synchronize do
        @tag_registry[tag_sym] = {
          category: category,
          backend_name: derived_backend,
          require_path: require_path,
          checker: callable,
        }
        # Also register as availability checker for the backend name
        @availability_checkers[derived_backend] = callable
        # Clear caches
        @availability_cache.delete(derived_backend)
      end

      # Dynamically define the availability method on DependencyTags
      # This happens outside the mutex to avoid potential deadlock
      define_availability_method(derived_backend, tag_sym)

      nil
    end

    # Register an availability checker for a backend (simple form)
    #
    # The checker should be a callable (lambda/proc/block) that returns true if
    # the backend is available and can be used. The checker is called lazily
    # (only when {available?} is first called for this backend).
    #
    # For full tag support including require paths, use {register_tag} instead.
    #
    # @param backend_name [Symbol, String] the backend name (e.g., :commonmarker, :markly)
    # @param checker [#call, nil] a callable that returns true if the backend is available
    # @yield Block form of checker (alternative to passing a callable)
    # @yieldreturn [Boolean] true if the backend is available
    # @return [void]
    # @raise [ArgumentError] if no checker callable or block is provided
    # @raise [ArgumentError] if checker doesn't respond to #call
    #
    # @example Register with a block
    #   TreeHaver::BackendRegistry.register_availability_checker(:commonmarker) do
    #     require "commonmarker"
    #     true
    #   rescue LoadError
    #     false
    #   end
    #
    # @example Register with a lambda
    #   checker = -> { Commonmarker::Merge::Backend.available? }
    #   TreeHaver::BackendRegistry.register_availability_checker(:commonmarker, checker)
    #
    # @example Register referencing the module's available? method
    #   TreeHaver::BackendRegistry.register_availability_checker(:my_backend) do
    #     available?  # Calls the enclosing module's available? method
    #   end
    def register_availability_checker(backend_name, checker = nil, &block)
      callable = checker || block
      raise ArgumentError, "Must provide a checker callable or block" unless callable
      raise ArgumentError, "Checker must respond to #call" unless callable.respond_to?(:call)

      @mutex.synchronize do
        @availability_checkers[backend_name.to_sym] = callable
        # Clear cache for this backend when re-registering
        @availability_cache.delete(backend_name.to_sym)
      end
      nil
    end

    # Check if a backend is available
    #
    # If a checker was registered via {register_availability_checker}, it is called
    # (and the result cached). If no checker is registered, falls back to checking
    # `TreeHaver::Backends::<Name>.available?` for built-in backends.
    #
    # Results are cached to avoid repeated expensive checks (e.g., requiring gems).
    # Use {clear_cache!} to reset the cache if backend availability may have changed.
    #
    # @param backend_name [Symbol, String] the backend name to check
    # @return [Boolean] true if the backend is available, false otherwise
    #
    # @example
    #   TreeHaver::BackendRegistry.available?(:commonmarker)  # => true
    #   TreeHaver::BackendRegistry.available?(:nonexistent)   # => false
    def available?(backend_name)
      key = backend_name.to_sym

      # First, check cache and get checker without holding mutex for long
      checker = nil
      @mutex.synchronize do
        # Return cached result if available
        return @availability_cache[key] if @availability_cache.key?(key)

        # Get registered checker (if any)
        checker = @availability_checkers[key]
      end

      # Compute result OUTSIDE the mutex to avoid deadlock when loading backends
      # (loading a backend module triggers register_availability_checker which needs the mutex)
      result = if checker
        # Use the registered checker
        begin
          checker.call
        rescue StandardError
          false
        end
      else
        # Fall back to checking TreeHaver::Backends::<Name>
        # This may load the backend module, which will register its checker
        check_builtin_backend(key)
      end

      # Cache the result
      @mutex.synchronize do
        # Double-check cache in case another thread computed it
        return @availability_cache[key] if @availability_cache.key?(key)
        @availability_cache[key] = result
      end

      result
    end

    # Check if an availability checker is registered for a backend
    #
    # @param backend_name [Symbol, String] the backend name
    # @return [Boolean] true if a checker is registered
    #
    # @example
    #   TreeHaver::BackendRegistry.registered?(:commonmarker)  # => true (if loaded)
    #   TreeHaver::BackendRegistry.registered?(:nonexistent)   # => false
    def registered?(backend_name)
      @mutex.synchronize do
        @availability_checkers.key?(backend_name.to_sym)
      end
    end

    # Get all registered backend names
    #
    # @return [Array<Symbol>] list of registered backend names
    #
    # @example
    #   TreeHaver::BackendRegistry.registered_backends
    #   # => [:mri, :rust, :ffi, :java, :prism, :psych, :citrus, :commonmarker, :markly]
    def registered_backends
      @mutex.synchronize do
        @availability_checkers.keys.dup
      end
    end

    # Clear the availability cache
    #
    # Useful for testing or when backend availability may have changed
    # (e.g., after installing a gem mid-process).
    #
    # @return [void]
    #
    # @example
    #   TreeHaver::BackendRegistry.clear_cache!
    #   # Next call to available? will re-check
    def clear_cache!
      @mutex.synchronize do
        @availability_cache.clear
      end
      nil
    end

    # Clear all registrations and cache
    #
    # Removes all registered checkers and cached results.
    # Primarily useful for testing to reset state between test cases.
    #
    # @return [void]
    #
    # @example
    #   TreeHaver::BackendRegistry.clear!
    def clear!
      @mutex.synchronize do
        @availability_checkers.clear
        @availability_cache.clear
        @tag_registry.clear
      end
      nil
    end

    # ============================================================
    # Tag Registry Methods
    # ============================================================

    # Get all registered tag names
    #
    # @return [Array<Symbol>] list of registered tag names
    #
    # @example
    #   TreeHaver::BackendRegistry.registered_tags
    #   # => [:commonmarker_backend, :markly_backend, :toml_gem, ...]
    def registered_tags
      @mutex.synchronize do
        @tag_registry.keys.dup
      end
    end

    # Get tags filtered by category
    #
    # @param category [Symbol] one of :backend, :gem, :parsing, :grammar, :engine, :other
    # @return [Array<Symbol>] list of tag names in that category
    #
    # @example
    #   TreeHaver::BackendRegistry.tags_by_category(:backend)
    #   # => [:commonmarker_backend, :markly_backend, :mri_backend, ...]
    def tags_by_category(category)
      @mutex.synchronize do
        @tag_registry.select { |_, meta| meta[:category] == category }.keys
      end
    end

    # Get tag metadata
    #
    # @param tag_name [Symbol] the tag name
    # @return [Hash, nil] tag metadata or nil if not registered
    #
    # @example
    #   TreeHaver::BackendRegistry.tag_metadata(:commonmarker_backend)
    #   # => { category: :backend, backend_name: :commonmarker, require_path: "commonmarker/merge", checker: #<Proc> }
    def tag_metadata(tag_name)
      @mutex.synchronize do
        @tag_registry[tag_name.to_sym]&.dup
      end
    end

    # Check if a tag is registered
    #
    # @param tag_name [Symbol] the tag name
    # @return [Boolean] true if the tag is registered
    def tag_registered?(tag_name)
      @mutex.synchronize do
        @tag_registry.key?(tag_name.to_sym)
      end
    end

    # Check if a tag's dependency is available
    #
    # This method handles require paths: if the tag has a require_path, it will
    # attempt to load the gem before checking availability. This enables lazy
    # loading of external gems.
    #
    # @param tag_name [Symbol] the tag name to check
    # @return [Boolean] true if the tag's dependency is available
    #
    # @example
    #   TreeHaver::BackendRegistry.tag_available?(:commonmarker_backend)  # => true/false
    def tag_available?(tag_name)
      tag_sym = tag_name.to_sym

      # Get tag metadata
      meta = @mutex.synchronize { @tag_registry[tag_sym] }

      # If tag not registered, check if it's a backend name with _backend suffix
      unless meta
        # Try to derive backend name (e.g., :commonmarker_backend -> :commonmarker)
        backend_name = tag_sym.to_s.sub(/_backend$/, "").to_sym
        return available?(backend_name) if backend_name != tag_sym
        return false
      end

      # Try to load the gem if require_path is specified
      if meta[:require_path]
        begin
          require meta[:require_path]
        rescue LoadError
          # Gem not available
          return false
        end
      end

      # Check availability using the backend name
      available?(meta[:backend_name])
    end

    # Get a summary of all registered tags and their availability
    #
    # @return [Hash{Symbol => Boolean}] map of tag name to availability
    #
    # @example
    #   TreeHaver::BackendRegistry.tag_summary
    #   # => { commonmarker_backend: true, markly_backend: false, ... }
    def tag_summary
      @mutex.synchronize { @tag_registry.keys.dup }.each_with_object({}) do |tag, result|
        result[tag] = tag_available?(tag)
      end
    end

    # Check a built-in TreeHaver backend
    #
    # Attempts to find the backend module at `TreeHaver::Backends::<Name>` and
    # call its `available?` method. This is the fallback when no explicit
    # checker has been registered.
    #
    # @param backend_name [Symbol] the backend name (e.g., :mri, :rust, :ffi)
    # @return [Boolean] true if the backend module exists and reports available
    # @api private
    def check_builtin_backend(backend_name)
      # Convert backend_name to PascalCase constant name
      # e.g., :mri -> "MRI", :ffi -> "FFI", :commonmarker -> "Commonmarker"
      const_name = backend_name.to_s.split("_").map(&:capitalize).join
      backend_mod = TreeHaver::Backends.const_get(const_name)
      backend_mod.respond_to?(:available?) && backend_mod.available?
    rescue NameError
      # Backend module doesn't exist
      false
    end
    private_class_method :check_builtin_backend

    # Dynamically define an availability method on DependencyTags
    #
    # This creates a `*_available?` method that checks tag_available? with
    # memoization. The method is only defined if DependencyTags is loaded
    # and doesn't already have a method with that name.
    #
    # @param backend_name [Symbol] the backend name (e.g., :commonmarker)
    # @param tag_name [Symbol] the tag name (e.g., :commonmarker_backend)
    # @return [void]
    # @api private
    def define_availability_method(backend_name, tag_name)
      method_name = :"#{backend_name}_available?"

      # Only define if DependencyTags is loaded
      return unless defined?(TreeHaver::RSpec::DependencyTags)

      deps = TreeHaver::RSpec::DependencyTags

      # Don't override existing methods (built-in backends have explicit methods)
      return if deps.respond_to?(method_name)

      # Define the method dynamically
      ivar = :"@#{backend_name}_available"
      deps.define_singleton_method(method_name) do
        return instance_variable_get(ivar) if instance_variable_defined?(ivar)
        instance_variable_set(ivar, TreeHaver::BackendRegistry.tag_available?(tag_name))
      end
    end
    private_class_method :define_availability_method
  end
end
