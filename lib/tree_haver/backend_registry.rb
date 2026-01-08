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
  # == Thread Safety
  #
  # All operations are thread-safe using a Mutex for synchronization.
  # Results are cached after first check for performance.
  #
  # @example Registering a backend availability checker (in your gem)
  #   # In commonmarker-merge/lib/commonmarker/merge/backend.rb
  #   TreeHaver::BackendRegistry.register_availability_checker(:commonmarker) do
  #     available?
  #   end
  #
  # @example Checking backend availability
  #   TreeHaver::BackendRegistry.available?(:commonmarker)  # => true/false
  #   TreeHaver::BackendRegistry.available?(:markly)        # => true/false
  #   TreeHaver::BackendRegistry.available?(:rbs)           # => true/false
  #
  # @example Checking if a checker is registered
  #   TreeHaver::BackendRegistry.registered?(:commonmarker) # => true/false
  #
  # @example Getting all registered backends
  #   TreeHaver::BackendRegistry.registered_backends # => [:mri, :rust, :ffi, ...]
  #
  # @see TreeHaver::RSpec::DependencyTags Uses BackendRegistry for dynamic backend detection
  # @api public
  module BackendRegistry
    @mutex = Mutex.new
    @availability_checkers = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable
    @availability_cache = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable

    module_function

    # Register an availability checker for a backend
    #
    # The checker should be a callable (lambda/proc/block) that returns true if
    # the backend is available and can be used. The checker is called lazily
    # (only when {available?} is first called for this backend).
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
      end
      nil
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
  end
end
