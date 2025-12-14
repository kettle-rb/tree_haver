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
    def initialize(language_name, extra_paths: [])
      @language_name = language_name.to_sym
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
    # 1. Environment variable override
    # 2. Extra paths provided at initialization
    # 3. Common system installation paths
    #
    # @return [String, nil] the path to the library, or nil if not found
    def find_library_path
      # Check environment variable first (highest priority)
      env_path = ENV[env_var_name]
      return env_path if env_path && File.exist?(env_path)

      # Search all paths
      search_paths.find { |path| File.exist?(path) }
    end

    # Check if the grammar library is available
    #
    # @return [Boolean] true if the library can be found
    def available?
      !find_library_path.nil?
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
        "Searched: #{search_paths.join(', ')}. " \
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

