# frozen_string_literal: true

require "rbconfig"

module TreeHaver
  # Generic utility for finding tree-sitter grammar shared libraries.
  #
  # GrammarFinder provides platform-aware discovery of tree-sitter grammar
  # libraries. Given a language name, it searches common installation paths
  # and supports environment variable overrides.
  #
  # This class is designed to be used by language-specific merge gems
  # (toml-merge, json-merge, bash-merge, etc.) without requiring TreeHaver
  # to have knowledge of each specific language.
  #
  # == Security Considerations
  #
  # Loading shared libraries is inherently dangerous as it executes arbitrary
  # native code. GrammarFinder performs the following security validations:
  #
  # - Language names are validated to contain only safe characters
  # - Paths from environment variables are validated before use
  # - Path traversal attempts (../) are rejected
  # - Only files with expected extensions (.so, .dylib, .dll) are accepted
  #
  # For additional security, use {#find_library_path_safe} which only returns
  # paths from trusted system directories.
  #
  # @example Basic usage
  #   finder = TreeHaver::GrammarFinder.new(:toml)
  #   path = finder.find_library_path
  #   # => "/usr/lib/libtree-sitter-toml.so"
  #
  # @example Check availability
  #   finder = TreeHaver::GrammarFinder.new(:json)
  #   if finder.available?
  #     language = TreeHaver::Language.load(finder.language_name, finder.find_library_path)
  #   end
  #
  # @example Register with TreeHaver
  #   finder = TreeHaver::GrammarFinder.new(:bash)
  #   finder.register! if finder.available?
  #   # Now you can use: TreeHaver::Language.bash
  #
  # @example With custom search paths
  #   finder = TreeHaver::GrammarFinder.new(:toml, extra_paths: ["/opt/custom/lib"])
  #
  # @example Secure mode (trusted directories only)
  #   finder = TreeHaver::GrammarFinder.new(:toml)
  #   path = finder.find_library_path_safe  # Only returns paths in trusted dirs
  #
  # @see PathValidator For details on security validations
  class GrammarFinder
    # Common base directories where tree-sitter libraries are installed
    # Platform-specific extensions are appended automatically
    BASE_SEARCH_DIRS = [
      "/usr/lib",
      "/usr/lib64",
      "/usr/local/lib",
      "/opt/homebrew/lib",
    ].freeze

    # @return [Symbol] the language identifier
    attr_reader :language_name

    # @return [Array<String>] additional search paths provided at initialization
    attr_reader :extra_paths

    # Initialize a grammar finder for a specific language
    #
    # @param language_name [Symbol, String] the tree-sitter language name (e.g., :toml, :json, :bash)
    # @param extra_paths [Array<String>] additional paths to search (searched first after ENV)
    # @param validate [Boolean] if true, validates the language name (default: true)
    # @raise [ArgumentError] if language_name is invalid and validate is true
    def initialize(language_name, extra_paths: [], validate: true)
      name_str = language_name.to_s.downcase

      if validate && !PathValidator.safe_language_name?(name_str)
        raise ArgumentError, "Invalid language name: #{language_name.inspect}. " \
          "Language names must start with a letter and contain only lowercase letters, numbers, and underscores."
      end

      @language_name = name_str.to_sym
      @extra_paths = Array(extra_paths)
    end

    # Get the environment variable name for this language
    #
    # @return [String] the ENV var name (e.g., "TREE_SITTER_TOML_PATH")
    def env_var_name
      "TREE_SITTER_#{@language_name.to_s.upcase}_PATH"
    end

    # Get the expected symbol name exported by the grammar library
    #
    # @return [String] the symbol name (e.g., "tree_sitter_toml")
    def symbol_name
      "tree_sitter_#{@language_name}"
    end

    # Get the library filename for the current platform
    #
    # @return [String] the library filename (e.g., "libtree-sitter-toml.so")
    def library_filename
      ext = platform_extension
      "libtree-sitter-#{@language_name}#{ext}"
    end

    # Generate the full list of search paths for this language
    #
    # Order: ENV override, extra_paths, then common system paths
    #
    # @return [Array<String>] all paths to search
    def search_paths
      paths = []

      # Extra paths provided at initialization (searched after ENV)
      @extra_paths.each do |dir|
        paths << File.join(dir, library_filename)
      end

      # Common system paths with platform-appropriate extension
      BASE_SEARCH_DIRS.each do |dir|
        paths << File.join(dir, library_filename)
      end

      paths
    end

    # Find the grammar library path
    #
    # Searches in order:
    # 1. Environment variable override (validated for safety)
    # 2. Extra paths provided at initialization
    # 3. Common system installation paths
    #
    # @note Paths from ENV are validated using {PathValidator.safe_library_path?}
    #   to prevent path traversal and other attacks. Invalid ENV paths are ignored.
    #
    # @return [String, nil] the path to the library, or nil if not found
    # @see #find_library_path_safe For stricter validation (trusted directories only)
    def find_library_path
      # Check environment variable first (highest priority)
      env_path = ENV[env_var_name]
      if env_path && PathValidator.safe_library_path?(env_path) && File.exist?(env_path)
        return env_path
      end

      # Search all paths (these are constructed from trusted base dirs)
      search_paths.find { |path| File.exist?(path) }
    end

    # Find the grammar library path with strict security validation
    #
    # This method only returns paths that are in trusted system directories.
    # Use this when you want maximum security and don't need to support
    # custom installation locations.
    #
    # @return [String, nil] the path to the library, or nil if not found
    # @see PathValidator::TRUSTED_DIRECTORIES For the list of trusted directories
    def find_library_path_safe
      # Environment variable is NOT checked in safe mode - only trusted system paths
      search_paths.find do |path|
        File.exist?(path) && PathValidator.in_trusted_directory?(path)
      end
    end

    # Check if the grammar library is available
    #
    # @return [Boolean] true if the library can be found
    def available?
      !find_library_path.nil?
    end

    # Check if the grammar library is available in a trusted directory
    #
    # @return [Boolean] true if the library can be found in a trusted directory
    # @see #find_library_path_safe
    def available_safe?
      !find_library_path_safe.nil?
    end

    # Register this language with TreeHaver
    #
    # After registration, the language can be loaded via dynamic method
    # (e.g., `TreeHaver::Language.toml`).
    #
    # @param raise_on_missing [Boolean] if true, raises when library not found
    # @return [Boolean] true if registration succeeded
    # @raise [NotAvailable] if library not found and raise_on_missing is true
    def register!(raise_on_missing: false)
      path = find_library_path
      unless path
        if raise_on_missing
          raise NotAvailable, not_found_message
        end
        return false
      end

      TreeHaver.register_language(@language_name, path: path, symbol: symbol_name)
      true
    end

    # Get debug information about the search
    #
    # @return [Hash] diagnostic information
    def search_info
      {
        language: @language_name,
        env_var: env_var_name,
        env_value: ENV[env_var_name],
        symbol: symbol_name,
        library_filename: library_filename,
        search_paths: search_paths,
        found_path: find_library_path,
        available: available?,
      }
    end

    # Get a human-readable error message when library is not found
    #
    # @return [String] error message with installation hints
    def not_found_message
      "Tree-sitter #{@language_name} grammar not found. " \
        "Searched: #{search_paths.join(", ")}. " \
        "Install tree-sitter-#{@language_name} or set #{env_var_name}."
    end

    private

    # Get the platform-appropriate shared library extension
    #
    # @return [String] ".so" on Linux, ".dylib" on macOS
    def platform_extension
      case RbConfig::CONFIG["host_os"]
      when /darwin/i
        ".dylib"
      when /mswin|mingw|cygwin/i
        ".dll"
      else
        ".so"
      end
    end
  end
end
