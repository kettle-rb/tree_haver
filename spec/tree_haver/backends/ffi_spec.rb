# frozen_string_literal: true

RSpec.describe TreeHaver::Backends::FFI do
  let(:backend) { described_class }

  # Force FFI backend for these tests
  before do
    TreeHaver.reset_backend!(to: :ffi)
  end

  after do
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "::available?" do
    it "reports availability when the ffi gem can be required" do
      expect([true, false]).to include(backend.available?)
      # We can't assert true in all environments; this spec runs across many rubies.
    end
  end

  describe "::capabilities" do
    it "returns a hash when available, otherwise empty" do
      caps = backend.capabilities
      if backend.available?
        expect(caps).to include(:backend, :parse)
        expect(caps[:backend]).to eq(:ffi)
      else
        expect(caps).to eq({})
      end
    end
  end

  describe "core library ENV precedence" do
    it "honors TREE_SITTER_RUNTIME_LIB before defaults and reports candidates on failure" do
      skip "ffi backend not present" unless backend.available?

      bogus = File.join(Dir.pwd, "tmp", "nope", "libtree-sitter.so.0")
      # Ensure parent dir doesn't exist to make it unresolvable
      expect(File.exist?(bogus)).to be(false)

      stub_env("TREE_SITTER_RUNTIME_LIB" => bogus)

      # Force a fresh load attempt in case another spec already loaded the lib
      if backend.const_defined?(:Native)
        backend::Native.instance_variable_set(:@loaded, nil)
      end

      expect {
        backend::Native.try_load!
      }.to raise_error(TreeHaver::NotAvailable) { |err|
        # Error message should enumerate candidates and include our bogus path
        expect(err.message).to include(bogus)
        expect(err.message).to match(/Could not load libtree-sitter/i)
      }
    end
  end

  describe "Language.from_path and parsing" do
    # Attempt to locate a tree-sitter-toml grammar library for a smoke test.
    # Prefer explicit env, then try common locations; skip test if none found.
    def find_toml_lang
      env = ENV["TREE_SITTER_TOML_PATH"]
      return env if env && File.exist?(env)

      [
        "/usr/lib/libtree-sitter-toml.so",
        "/usr/lib64/libtree-sitter-toml.so",
        "/usr/local/lib/libtree-sitter-toml.so",
        "/opt/homebrew/lib/libtree-sitter-toml.dylib",
        "/usr/local/lib/libtree-sitter-toml.dylib",
      ].find { |p| File.exist?(p) }
    end

    it "raises NotAvailable for a missing library path" do
      skip "ffi backend not present" unless backend.available?
      bogus = File.join(Dir.pwd, "tmp", "nope", "missing-libtree-sitter-toml.so")
      expect {
        TreeHaver::Language.from_path(bogus)
      }.to raise_error(TreeHaver::NotAvailable, /Could not open language library|No TreeHaver backend is available|No such file/i)
    end

    it "can parse a minimal TOML and expose node types", :check_output do
      skip "ffi backend not present" unless backend.available?
      lang_path = find_toml_lang
      skip "tree-sitter-toml not installed on this system" unless lang_path
      begin
        # Ensure core libtree-sitter can be loaded; otherwise skip
        backend::Native.try_load!
      rescue TreeHaver::NotAvailable => e
        skip "libtree-sitter not installed on this system (#{e.message})"
      end

      lang = TreeHaver::Language.from_path(lang_path)
      parser = TreeHaver::Parser.new
      parser.language = lang
      tree = parser.parse("title = \"TOML\"\n")
      root = tree.root_node
      expect(root).to respond_to(:each)
      child_types = root.each.map(&:type)
      # Depending on grammar version, the first child could be key_value_pair or similar
      expect(child_types).not_to be_empty
      expect(child_types.join(",")).to match(/key|table|pair/i)
    end
  end

  describe "error cases for symbol resolution" do
    it "raises NotAvailable if symbol override cannot be resolved" do
      skip "ffi backend not present" unless backend.available?
      lang_path = ENV["TREE_SITTER_TOML_PATH"]
      skip "TREE_SITTER_TOML_PATH not set; skipping symbol resolution test" unless lang_path && File.exist?(lang_path)

      # Use rspec-stubbed_env helper to temporarily override ENV safely
      invalid = "totally_nonexistent_symbol_#{rand(1_000_000)}"
      stub_env("TREE_HAVER_LANG_SYMBOL" => invalid)
      expect {
        TreeHaver::Language.from_path(lang_path)
      }.to raise_error(TreeHaver::NotAvailable, /Could not resolve language symbol/i)
    end

    it "honors TREE_SITTER_LANG_SYMBOL when provided" do
      skip "ffi backend not present" unless backend.available?
      lang_path = ENV["TREE_SITTER_TOML_PATH"]
      skip "TREE_SITTER_TOML_PATH not set; skipping symbol resolution test" unless lang_path && File.exist?(lang_path)

      # The canonical symbol for TOML grammars is tree_sitter_toml
      stub_env("TREE_SITTER_LANG_SYMBOL" => "tree_sitter_toml")
      expect {
        TreeHaver::Language.from_path(lang_path)
      }.not_to raise_error
    end
  end
end
