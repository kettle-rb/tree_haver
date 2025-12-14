# frozen_string_literal: true

# External gems
require "version_gem"

# This gem
require_relative "tree_haver/version"
require_relative "tree_haver/language_registry"

module TreeHaver
  # Base error class for TreeHaver
  class Error < StandardError; end

  # Raised when a requested backend or feature is not available
  class NotAvailable < Error; end

  module Backends
    autoload :MRI, File.join(__dir__, "tree_haver", "backends", "mri")
    autoload :FFI, File.join(__dir__, "tree_haver", "backends", "ffi")
    autoload :Java, File.join(__dir__, "tree_haver", "backends", "java")
  end

  # Select backend: :auto (default), :mri, :ffi, :java
  def self.backend
    @backend ||= begin
      case (ENV["TREE_HAVER_BACKEND"] || :auto).to_s
      when "mri" then :mri
      when "ffi" then :ffi
      when "java" then :java
      else :auto
      end
    end
  end

  def self.backend=(name)
    @backend = name&.to_sym
  end

  # Test/helper: reset backend selection memoization.
  # Allows specs to switch backends without cross-example leakage.
  # @param to [Symbol, String, nil] backend name or nil to clear (defaults to :auto)
  # @return [void]
  def self.reset_backend!(to: :auto)
    @backend = (to && to.to_sym)
  end

  # Determine the concrete backend module to use, without eagerly requiring
  def self.backend_module
    case backend
    when :mri
      Backends::MRI
    when :ffi
      Backends::FFI
    when :java
      Backends::Java
    else
      # auto-select: on JRuby prefer Java backend if available; on MRI prefer MRI; otherwise FFI
      if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby" && Backends::Java.available?
        Backends::Java
      elsif defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby" && Backends::MRI.available?
        Backends::MRI
      elsif Backends::FFI.available?
        Backends::FFI
      else
        # No backend available yet
        nil
      end
    end
  end

  # A simple capability map exposed at runtime
  def self.capabilities
    mod = backend_module
    return {} unless mod
    mod.capabilities
  end

  # -- Language registration API -------------------------------------------------
  # Delegates to LanguageRegistry for thread-safe registration and lookup.
  # Allows opting-in dynamic helpers like TreeHaver::Language.toml without
  # advertising all names by default.

  # Register a language helper by name.
  # @param name [Symbol, String]
  # @param path [String] absolute path to the language shared library
  # @param symbol [String, nil] optional exported factory symbol (e.g. "tree_sitter_toml")
  # @return [void]
  def self.register_language(name, path:, symbol: nil)
    LanguageRegistry.register(name, path: path, symbol: symbol)
  end

  # Unregister a previously registered language helper.
  # @param name [Symbol, String]
  # @return [void]
  def self.unregister_language(name)
    LanguageRegistry.unregister(name)
  end

  # Clear all registered languages (intended for test cleanup).
  # @return [void]
  def self.clear_languages!
    LanguageRegistry.clear_registrations!
  end

  # Fetch a registered language entry.
  # @api private
  # @return [Hash, nil] with keys :path and :symbol
  def self.registered_language(name)
    LanguageRegistry.registered(name)
  end

  # Public API types delegating to the selected backend implementation
  class Language
    def self.from_library(path, symbol: nil, name: nil)
      mod = TreeHaver.backend_module
      raise NotAvailable, "No TreeHaver backend is available" unless mod
      # Backend must implement .from_library; fallback to .from_path for older impls
      key = [path, symbol, name]
      LanguageRegistry.fetch(key) do
        if mod::Language.respond_to?(:from_library)
          mod::Language.from_library(path, symbol: symbol, name: name)
        else
          mod::Language.from_path(path)
        end
      end
    end

    class << self
      alias from_path from_library

      # Dynamic helper to load a language by name, e.g. Language.toml(path: "/path/libtree-sitter-toml.so")
      def method_missing(method_name, *args, **kwargs, &block)
        # Resolve only if the language name was registered
        reg = TreeHaver.registered_language(method_name)
        return super unless reg

        # Allow per-call overrides; otherwise use registered defaults
        path = kwargs[:path] || args.first || reg[:path]
        raise ArgumentError, "path is required" unless path
        symbol = kwargs.key?(:symbol) ? kwargs[:symbol] : (reg[:symbol] || "tree_sitter_#{method_name}")
        name = kwargs[:name] || method_name.to_s
        return from_library(path, symbol: symbol, name: name)
      end

      def respond_to_missing?(method_name, include_private = false)
        !!TreeHaver.registered_language(method_name) || super
      end
    end
  end

  class Parser
    def initialize
      mod = TreeHaver.backend_module
      raise NotAvailable, "No TreeHaver backend is available" unless mod
      @impl = mod::Parser.new
    end

    def language=(lang)
      @impl.language = lang
    end

    def parse(source)
      tree_impl = @impl.parse(source)
      Tree.new(tree_impl)
    end
  end

  class Tree
    def initialize(impl)
      @impl = impl
    end

    def root_node
      Node.new(@impl.root_node)
    end
  end

  class Node
    def initialize(impl)
      @impl = impl
    end

    def type
      @impl.type
    end

    def each(&blk)
      return enum_for(:each) unless block_given?
      @impl.each { |child_impl| blk.call(Node.new(child_impl)) }
    end
  end
end

TreeHaver::Version.class_eval do
  extend VersionGem::Basic
end
