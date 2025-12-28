# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::GrammarFinder do
  let(:finder) { described_class.new(:toml) }

  after do
    # Clean up any cached state
    described_class.reset_runtime_check!
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "#initialize" do
    it "creates a finder with valid language name" do
      finder = described_class.new(:toml)
      expect(finder.language_name).to eq(:toml)
    end

    it "converts string to symbol" do
      finder = described_class.new("json")
      expect(finder.language_name).to eq(:json)
    end

    it "downcases language name" do
      finder = described_class.new(:TOML)
      expect(finder.language_name).to eq(:toml)
    end

    it "accepts extra_paths option" do
      finder = described_class.new(:toml, extra_paths: ["/custom/lib"])
      expect(finder.extra_paths).to eq(["/custom/lib"])
    end

    it "validates language name by default" do
      expect {
        described_class.new("../evil")
      }.to raise_error(ArgumentError, /Invalid language name/)
    end

    it "allows skipping validation" do
      expect {
        described_class.new("../evil", validate: false)
      }.not_to raise_error
    end

    it "rejects names starting with numbers" do
      expect {
        described_class.new("123abc")
      }.to raise_error(ArgumentError, /Invalid language name/)
    end

    it "accepts underscores in names" do
      finder = described_class.new(:tree_sitter_cpp)
      expect(finder.language_name).to eq(:tree_sitter_cpp)
    end
  end

  describe "#env_var_name" do
    it "returns uppercase ENV var name" do
      expect(finder.env_var_name).to eq("TREE_SITTER_TOML_PATH")
    end

    it "handles underscores" do
      finder = described_class.new(:cpp)
      expect(finder.env_var_name).to eq("TREE_SITTER_CPP_PATH")
    end
  end

  describe "#symbol_name" do
    it "returns tree_sitter_ prefixed symbol" do
      expect(finder.symbol_name).to eq("tree_sitter_toml")
    end
  end

  describe "#library_filename" do
    it "returns platform-appropriate filename" do
      filename = finder.library_filename
      expect(filename).to match(/^libtree-sitter-toml\.(so|dylib|dll)$/)
    end

    context "when on Linux", if: RbConfig::CONFIG["host_os"] =~ /linux/i do
      it "uses .so extension" do
        expect(finder.library_filename).to eq("libtree-sitter-toml.so")
      end
    end

    context "when on macOS", if: RbConfig::CONFIG["host_os"] =~ /darwin/i do
      it "uses .dylib extension" do
        expect(finder.library_filename).to eq("libtree-sitter-toml.dylib")
      end
    end
  end

  describe "#search_paths" do
    it "returns array of paths" do
      paths = finder.search_paths
      expect(paths).to be_an(Array)
      expect(paths).not_to be_empty
    end

    it "includes common system paths" do
      paths = finder.search_paths
      # At least one of the common paths should be included
      common_dirs = ["/usr/lib", "/usr/local/lib"]
      expect(paths.any? { |p| common_dirs.any? { |d| p.start_with?(d) } }).to be true
    end

    it "prepends extra_paths" do
      finder = described_class.new(:toml, extra_paths: ["/custom/lib"])
      paths = finder.search_paths
      expect(paths.first).to match(%r{^/custom/lib/})
    end

    it "does not include ENV path in search_paths" do
      # ENV path is handled separately in find_library_path
      paths = finder.search_paths
      expect(paths).not_to include(nil)
    end
  end

  describe "#find_library_path" do
    context "without ENV override" do
      before do
        hide_env("TREE_SITTER_TOML_PATH")
      end

      it "returns nil when library not found" do
        # Mock File.exist? to always return false
        allow(File).to receive(:exist?).and_return(false)
        expect(finder.find_library_path).to be_nil
      end

      context "when library disabled" do
        before do
          stub_env("TREE_SITTER_TOML_PATH", "")
        end

        it "returns nil when library disabled" do
          expect(finder.find_library_path).to be_nil
        end
      end
    end

    context "with ENV override" do
      let(:env_path) { "/custom/path/libtree-sitter-toml.so" }

      context "with valid path" do
        before do
          stub_env("TREE_SITTER_TOML_PATH" => env_path)
          allow(File).to receive(:exist?).with(env_path).and_return(true)
          allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(true)
        end

        it "returns ENV path" do
          expect(finder.find_library_path).to eq(env_path)
        end
      end

      context "with empty ENV value" do
        before do
          stub_env("TREE_SITTER_TOML_PATH" => "")
        end

        it "returns nil (explicitly disabled)" do
          expect(finder.find_library_path).to be_nil
        end
      end

      context "with non-existent file" do
        before do
          stub_env("TREE_SITTER_TOML_PATH" => env_path)
          allow(File).to receive(:exist?).with(env_path).and_return(false)
          allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(true)
        end

        it "raises NotAvailable" do
          expect {
            finder.find_library_path
          }.to raise_error(TreeHaver::NotAvailable, /file does not exist/)
        end
      end

      context "with unsafe path" do
        before do
          stub_env("TREE_SITTER_TOML_PATH" => env_path)
          allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            finder.find_library_path
          }.to raise_error(TreeHaver::NotAvailable, /failed security validation/)
        end
      end

      context "with whitespace in path" do
        before do
          stub_env("TREE_SITTER_TOML_PATH" => " #{env_path} ")
        end

        it "raises NotAvailable with helpful message" do
          expect {
            finder.find_library_path
          }.to raise_error(TreeHaver::NotAvailable, /leading or trailing whitespace/)
        end
      end
    end
  end

  describe "#find_library_path_safe" do
    it "returns nil when library not in trusted directory" do
      allow(File).to receive(:exist?).and_return(true)
      allow(TreeHaver::PathValidator).to receive(:in_trusted_directory?).and_return(false)
      expect(finder.find_library_path_safe).to be_nil
    end

    it "returns path when in trusted directory" do
      expected_path = finder.search_paths.first
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:exist?).with(expected_path).and_return(true)
      allow(TreeHaver::PathValidator).to receive(:in_trusted_directory?).and_return(true)
      expect(finder.find_library_path_safe).to eq(expected_path)
    end

    it "ignores ENV variable in safe mode" do
      stub_env("TREE_SITTER_TOML_PATH" => "/custom/evil/path.so")
      # Should not use ENV path, only search_paths
      allow(File).to receive(:exist?).and_return(false)
      allow(TreeHaver::PathValidator).to receive(:in_trusted_directory?).and_return(true)
      expect(finder.find_library_path_safe).to be_nil
    end
  end

  describe "#available?" do
    context "when library exists and runtime is usable" do
      before do
        allow(finder).to receive(:find_library_path).and_return("/path/to/lib.so")
        allow(described_class).to receive(:tree_sitter_runtime_usable?).and_return(true)
      end

      it "returns true" do
        expect(finder.available?).to be true
      end
    end

    context "when library not found" do
      before do
        allow(finder).to receive(:find_library_path).and_return(nil)
      end

      it "returns false" do
        expect(finder.available?).to be false
      end
    end

    context "when runtime not usable" do
      before do
        allow(finder).to receive(:find_library_path).and_return("/path/to/lib.so")
        allow(described_class).to receive(:tree_sitter_runtime_usable?).and_return(false)
      end

      it "returns false" do
        expect(finder.available?).to be false
      end
    end
  end

  describe "#available_safe?" do
    it "uses find_library_path_safe" do
      allow(finder).to receive(:find_library_path_safe).and_return(nil)
      expect(finder.available_safe?).to be false
    end

    it "returns true when safe path found" do
      allow(finder).to receive(:find_library_path_safe).and_return("/usr/lib/lib.so")
      expect(finder.available_safe?).to be true
    end
  end

  describe "#register!" do
    context "when library available" do
      before do
        allow(finder).to receive(:find_library_path).and_return("/path/to/lib.so")
        allow(TreeHaver).to receive(:register_language)
      end

      it "registers the language" do
        expect(TreeHaver).to receive(:register_language).with(
          :toml,
          path: "/path/to/lib.so",
          symbol: "tree_sitter_toml",
        )
        finder.register!
      end

      it "returns true" do
        expect(finder.register!).to be true
      end
    end

    context "when library not available" do
      before do
        allow(finder).to receive(:find_library_path).and_return(nil)
      end

      it "returns false by default" do
        expect(finder.register!).to be false
      end

      it "raises when raise_on_missing is true" do
        expect {
          finder.register!(raise_on_missing: true)
        }.to raise_error(TreeHaver::NotAvailable)
      end
    end
  end

  describe "#search_info" do
    before do
      stub_env("TREE_SITTER_TOML_PATH" => nil)
      allow(File).to receive(:exist?).and_return(false)
    end

    it "returns diagnostic hash" do
      info = finder.search_info
      expect(info).to be_a(Hash)
      expect(info[:language]).to eq(:toml)
      expect(info[:env_var]).to eq("TREE_SITTER_TOML_PATH")
      expect(info[:symbol]).to eq("tree_sitter_toml")
      expect(info[:search_paths]).to be_an(Array)
    end

    it "includes found_path" do
      info = finder.search_info
      expect(info).to have_key(:found_path)
    end

    it "includes available status" do
      info = finder.search_info
      expect(info).to have_key(:available)
    end
  end

  describe "#not_found_message" do
    before do
      hide_env("TREE_SITTER_TOML_PATH")
      allow(File).to receive(:exist?).and_return(false)
      finder.find_library_path # Trigger search to populate internal state
    end

    it "returns helpful error message" do
      msg = finder.not_found_message
      expect(msg).to include("toml")
      expect(msg).to include("TREE_SITTER_TOML_PATH")
    end

    it "includes search paths" do
      msg = finder.not_found_message
      expect(msg).to include("Searched:")
    end
  end

  describe ".tree_sitter_runtime_usable?" do
    before do
      described_class.reset_runtime_check!
    end

    it "caches the result" do
      allow(TreeHaver).to receive(:resolve_backend_module).and_return(nil)
      result1 = described_class.tree_sitter_runtime_usable?
      result2 = described_class.tree_sitter_runtime_usable?
      expect(result1).to eq(result2)
      # Should only call resolve_backend_module once due to caching
    end

    it "returns false when backend module is nil" do
      allow(TreeHaver).to receive(:resolve_backend_module).and_return(nil)
      expect(described_class.tree_sitter_runtime_usable?).to be false
    end

    it "returns false for non-tree-sitter backends" do
      allow(TreeHaver).to receive(:resolve_backend_module).and_return(TreeHaver::Backends::Citrus)
      expect(described_class.tree_sitter_runtime_usable?).to be false
    end
  end

  describe ".reset_runtime_check!" do
    it "clears the cached runtime check" do
      # Set some cached state
      described_class.tree_sitter_runtime_usable?
      # Reset it
      described_class.reset_runtime_check!
      # Verify it's cleared
      expect(described_class.instance_variable_defined?(:@tree_sitter_runtime_usable)).to be false
    end
  end

  describe "#validate_env_path" do
    it "returns nil for valid path" do
      allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(true)
      allow(File).to receive(:exist?).and_return(true)
      expect(finder.send(:validate_env_path, "/valid/path.so")).to be_nil
    end

    it "returns reason for whitespace" do
      result = finder.send(:validate_env_path, " /path.so ")
      expect(result).to include("whitespace")
    end

    it "returns reason for unsafe path" do
      allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(false)
      result = finder.send(:validate_env_path, "/path.so")
      expect(result).to include("security validation")
    end

    it "returns reason for non-existent file" do
      allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(true)
      allow(File).to receive(:exist?).and_return(false)
      result = finder.send(:validate_env_path, "/nonexistent.so")
      expect(result).to include("does not exist")
    end
  end
end
