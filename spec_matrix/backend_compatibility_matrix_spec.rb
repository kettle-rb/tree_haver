# frozen_string_literal: true

require_relative "spec_matrix_helper"

# Comprehensive test matrix for backend compatibility
#
# This spec dynamically generates tests to determine which backend combinations
# work together and in which orders. The goal is to document and detect:
# - Which backends can be used after which other backends
# - Which backends share .so files and have symbol conflicts
# - Safe and unsafe backend transition patterns
#
# Known issues:
# - MRI (ruby_tree_sitter) statically links tree-sitter
# - FFI dynamically links libtree-sitter.so
# - When MRI loads first, FFI gets incompatible pointers and segfaults
# - For this reason, FFI tests MUST run in isolation BEFORE MRI loads
# - FFI is NOT included in this matrix - see ffi_spec.rb instead
# - Rust (tree_stump) may have similar issues to MRI
# - Citrus backend uses toml-rb gem which is pure ruby and unrelated to tree-sitter
# - TruffleRuby's FFI doesn't support STRUCT_BY_VALUE (used by tree-sitter)
#
# IMPORTANT: For accurate results, run with --order defined (not random):
#   bin/rspec spec_matrix/ --order defined
#
# With random order, citrus tests may run first and block all FFI tests.

RSpec.describe("Backend Compatibility Matrix", :toml_grammar) do
  # Define backends to test - only tree-sitter backends that share .so files
  # FFI is excluded because it must run in isolation (before MRI loads)
  # and cannot be tested in combination with other backends safely.
  # Citrus is excluded because it's pure Ruby (no .so conflicts).
  BACKENDS = [:mri, :rust].freeze # rubocop:disable RSpec/LeakyConstantDeclaration

  # Check if backend's required gems are INSTALLED without loading them
  # Uses Gem::Specification to avoid side effects from require
  class << self
    def gem_installed?(gem_name)
      Gem::Specification.find_by_name(gem_name)
      true
    rescue Gem::MissingSpecError
      false
    end
  end

  # rubocop:disable RSpec/LeakyConstantDeclaration
  MRI_GEM_INSTALLED = gem_installed?("ruby_tree_sitter")
  RUST_GEM_INSTALLED = gem_installed?("tree_stump")
  CITRUS_GEM_INSTALLED = gem_installed?("citrus")
  # rubocop:enable RSpec/LeakyConstantDeclaration

  # Check if backend's gem is installed (does NOT load the gem)
  def backend_gem_available?(backend)
    case backend
    when :mri then MRI_GEM_INSTALLED
    when :rust then RUST_GEM_INSTALLED
    when :citrus then CITRUS_GEM_INSTALLED
    else false
    end
  end

  # Check if a backend is blocked at runtime due to platform incompatibility or conflicts
  # Uses the backend's actual available? method for accurate detection
  def backend_blocked?(backend)
    case backend
    when :mri
      # MRI backend (ruby_tree_sitter) is a C extension, only works on MRI
      return true if RUBY_ENGINE != "ruby"
      # Check actual availability
      !TreeHaver::Backends::MRI.available?
    when :rust
      # Rust backend (tree_stump) uses magnus which requires MRI's C API
      return true if RUBY_ENGINE != "ruby"
      # Check actual availability
      !TreeHaver::Backends::Rust.available?
    else
      false
    end
  end

  # Get skip reason for a backend
  def skip_reason_for(backend)
    case backend
    when :mri
      return "MRI backend only works on MRI Ruby (C extension)" if RUBY_ENGINE != "ruby"
      return "MRI backend (ruby_tree_sitter) not available" unless TreeHaver::Backends::MRI.available?
    when :rust
      return "Rust backend only works on MRI Ruby (magnus requires MRI C API)" if RUBY_ENGINE != "ruby"
      return "Rust backend (tree_stump) not available" unless TreeHaver::Backends::Rust.available?
    end
    "#{backend} gem not installed"
  end

  # Check if backend can be used (gem installed AND not blocked)
  def backend_usable?(backend)
    backend_gem_available?(backend) && !backend_blocked?(backend)
  end

  # Get the Language class for a backend
  def language_class_for(backend)
    case backend
    when :mri then TreeHaver::Backends::MRI::Language
    when :rust then TreeHaver::Backends::Rust::Language
    when :citrus then TreeHaver::Backends::Citrus::Language
    end
  end

  # Load a language for the given backend
  def load_language_for(backend)
    path = TreeHaverDependencies.find_toml_grammar_path

    case backend
    when :citrus
      require "toml-rb"
      TreeHaver::Backends::Citrus::Language.new(TomlRB::Document)
    else
      TreeHaver.with_backend(backend) do
        TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
      end
    end
  end

  # Create a parser for the given backend
  def create_parser_for(backend)
    TreeHaver.with_backend(backend) do
      TreeHaver::Parser.new
    end
  end

  # Set language on parser and parse
  def parse_with(backend, language = nil)
    TreeHaver.with_backend(backend) do
      parser = TreeHaver::Parser.new
      lang = language || load_language_for(backend)
      parser.language = lang
      tree = parser.parse("x = 42")
      tree.root_node.type
    end
  end

  before do
    TreeHaver::LanguageRegistry.clear_cache!
    TreeHaver.reset_backend!(to: :auto)
  end

  after do
    TreeHaver::LanguageRegistry.clear_cache!
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "Single backend operations" do
    BACKENDS.each do |backend|
      context "with #{backend} backend" do
        it "can load language" do
          skip skip_reason_for(backend) unless backend_usable?(backend)

          lang = load_language_for(backend)
          expect(lang).to(be_a(language_class_for(backend)))
        end

        it "can create parser" do
          skip skip_reason_for(backend) unless backend_usable?(backend)

          parser = create_parser_for(backend)
          expect(parser).to(be_a(TreeHaver::Parser))
        end

        it "can parse source" do
          skip skip_reason_for(backend) unless backend_usable?(backend)

          result = parse_with(backend)
          expect(result).to(be_a(String))
        end
      end
    end
  end

  describe "Backend transition matrix (A then B)" do
    BACKENDS.each do |first_backend|
      BACKENDS.each do |second_backend|
        next if first_backend == second_backend

        context "when transitioning #{first_backend} -> #{second_backend}" do
          it "can parse with #{first_backend} then #{second_backend}" do
            skip skip_reason_for(first_backend) unless backend_usable?(first_backend)
            skip skip_reason_for(second_backend) unless backend_usable?(second_backend)

            # First backend parses
            result1 = nil
            begin
              result1 = parse_with(first_backend)
            rescue TreeHaver::NotAvailable, TreeHaver::BackendConflict => e
              skip("#{first_backend} failed to parse: #{e.message}")
            end
            expect(result1).to(be_a(String), "#{first_backend} should parse successfully")

            # Clear cache between backends
            TreeHaver::LanguageRegistry.clear_cache!

            # Second backend parses
            result2 = nil
            begin
              result2 = parse_with(second_backend)
            rescue TreeHaver::NotAvailable, TreeHaver::BackendConflict => e
              # Record this as a known incompatibility
              skip("#{first_backend} -> #{second_backend}: #{e.message}")
            end

            expect(result2).to(be_a(String), "#{second_backend} should parse after #{first_backend}")
          end
        end
      end
    end
  end

  describe "Backend transition matrix (A then B then A again)" do
    BACKENDS.each do |first_backend|
      BACKENDS.each do |second_backend|
        next if first_backend == second_backend

        context "when cycling #{first_backend} -> #{second_backend} -> #{first_backend}" do
          it "can return to #{first_backend} after using #{second_backend}" do
            skip skip_reason_for(first_backend) unless backend_usable?(first_backend)
            skip skip_reason_for(second_backend) unless backend_usable?(second_backend)

            # First backend parses
            begin
              parse_with(first_backend)
            rescue TreeHaver::NotAvailable, TreeHaver::BackendConflict => e
              skip("#{first_backend} failed initially: #{e.message}")
            end

            TreeHaver::LanguageRegistry.clear_cache!

            # Second backend parses
            begin
              parse_with(second_backend)
            rescue TreeHaver::NotAvailable, TreeHaver::BackendConflict => e
              skip("#{second_backend} failed: #{e.message}")
            end

            TreeHaver::LanguageRegistry.clear_cache!

            # Return to first backend
            result = nil
            begin
              result = parse_with(first_backend)
            rescue TreeHaver::NotAvailable, TreeHaver::BackendConflict => e
              skip("#{first_backend} -> #{second_backend} -> #{first_backend}: #{e.message}")
            end

            expect(result).to(be_a(String), "Should return to #{first_backend}")
          end
        end
      end
    end
  end

  describe "Full backend rotation" do
    it "can use all available backends in sequence" do
      available = BACKENDS.select { |b| backend_usable?(b) }
      skip "Need at least 2 backends" if available.size < 2

      results = {}

      available.each do |backend|
        TreeHaver::LanguageRegistry.clear_cache!
        begin
          results[backend] = parse_with(backend)
        rescue TreeHaver::NotAvailable, TreeHaver::BackendConflict => e
          results[backend] = "FAILED: #{e.message}"
        rescue => e
          results[backend] = "ERROR: #{e.class}: #{e.message}"
        end
      end

      # Report results
      # rubocop:disable RSpec/Output
      warn("\n=== Backend Rotation Results ===")
      results.each do |backend, result|
        status = (result.is_a?(String) && !result.start_with?("FAILED", "ERROR")) ? "✓" : "✗"
        warn("  #{status} #{backend}: #{result}")
      end
      warn("================================\n")
      # rubocop:enable RSpec/Output

      # At least the first backend should work
      first_result = results[available.first]
      expect(first_result).to(be_a(String))
      expect(first_result).not_to(start_with("FAILED", "ERROR"))
    end
  end

  describe "Shared .so file detection" do
    # These backends share tree-sitter .so grammar files
    # FFI is excluded because it must run in isolation before MRI loads
    TREE_SITTER_BACKENDS = [:mri, :rust].freeze # rubocop:disable RSpec/LeakyConstantDeclaration

    TREE_SITTER_BACKENDS.each do |first|
      TREE_SITTER_BACKENDS.each do |second|
        next if first == second

        context "when testing #{first} and #{second} (.so sharing)" do
          it "documents whether #{second} works after #{first} loads grammar" do
            skip skip_reason_for(first) unless backend_usable?(first)
            skip skip_reason_for(second) unless backend_usable?(second)

            # Load language with first backend (this loads the .so)
            begin
              load_language_for(first)
            rescue TreeHaver::NotAvailable, TreeHaver::BackendConflict => e
              skip("#{first} failed to load language: #{e.message}")
            end

            # Try to load with second backend (may get cached .so)
            TreeHaver::LanguageRegistry.clear_cache!

            lang2 = nil
            error = nil
            begin
              lang2 = load_language_for(second)
            rescue TreeHaver::NotAvailable, TreeHaver::BackendConflict => e
              error = e
            end

            if error
              # rubocop:disable RSpec/Output
              warn("\n[.so CONFLICT] #{first} -> #{second}: #{error.message}")
              # rubocop:enable RSpec/Output
              skip "#{first} -> #{second} has .so conflict: #{error.message}"
            else
              # Try to actually use the language
              begin
                parse_with(second, lang2)
                # rubocop:disable RSpec/Output
                warn("\n[.so OK] #{first} -> #{second}: Compatible")
              rescue TreeHaver::NotAvailable, TreeHaver::BackendConflict => e
                warn("\n[.so CONFLICT] #{first} -> #{second}: Load OK but parse failed: #{e.message}")
                # rubocop:enable RSpec/Output
                skip("#{first} -> #{second} loads but fails to parse: #{e.message}")
              end
            end
          end
        end
      end
    end
  end
end
