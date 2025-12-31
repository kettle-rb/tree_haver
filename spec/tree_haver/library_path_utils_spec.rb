# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::LibraryPathUtils do
  describe ".derive_symbol_from_path" do
    context "with nil path" do
      it "returns nil" do
        expect(described_class.derive_symbol_from_path(nil)).to be_nil
      end
    end

    context "with libtree-sitter-<lang>.so format (dashes)" do
      it "derives symbol from libtree-sitter-toml.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/libtree-sitter-toml.so")).to eq("tree_sitter_toml")
      end

      it "derives symbol from libtree-sitter-json.so" do
        expect(described_class.derive_symbol_from_path("/usr/local/lib/libtree-sitter-json.so")).to eq("tree_sitter_json")
      end

      it "derives symbol from libtree-sitter-ruby.so" do
        expect(described_class.derive_symbol_from_path("/opt/lib/libtree-sitter-ruby.so")).to eq("tree_sitter_ruby")
      end

      it "handles language names with dashes" do
        expect(described_class.derive_symbol_from_path("/usr/lib/libtree-sitter-c-sharp.so")).to eq("tree_sitter_c_sharp")
      end
    end

    context "with libtree_sitter_<lang>.so format (underscores)" do
      it "derives symbol from libtree_sitter_toml.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/libtree_sitter_toml.so")).to eq("tree_sitter_toml")
      end

      it "derives symbol from libtree_sitter_bash.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/libtree_sitter_bash.so")).to eq("tree_sitter_bash")
      end
    end

    context "with libtreesitter<lang>.so format (no separator after lib)" do
      it "treats the filename as a simple language name (libtreesitter-toml)" do
        # This format doesn't match the tree-sitter pattern, so it's treated as a simple name
        # The lib prefix is stripped and the result is "treesitter-toml" -> "tree_sitter_treesitter_toml"
        expect(described_class.derive_symbol_from_path("/usr/lib/libtreesitter-toml.so")).to eq("tree_sitter_treesitter_toml")
      end
    end

    context "with tree-sitter-<lang>.so format (no lib prefix)" do
      it "derives symbol from tree-sitter-toml.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/tree-sitter-toml.so")).to eq("tree_sitter_toml")
      end

      it "derives symbol from tree-sitter-python.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/tree-sitter-python.so")).to eq("tree_sitter_python")
      end
    end

    context "with tree_sitter_<lang>.so format (underscores, no lib prefix)" do
      it "derives symbol from tree_sitter_toml.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/tree_sitter_toml.so")).to eq("tree_sitter_toml")
      end

      it "derives symbol from tree_sitter_javascript.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/tree_sitter_javascript.so")).to eq("tree_sitter_javascript")
      end
    end

    context "with simple language name format" do
      it "derives symbol from toml.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/toml.so")).to eq("tree_sitter_toml")
      end

      it "derives symbol from json.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/json.so")).to eq("tree_sitter_json")
      end

      it "converts dashes to underscores" do
        expect(described_class.derive_symbol_from_path("/usr/lib/c-sharp.so")).to eq("tree_sitter_c_sharp")
      end
    end

    context "with libtoml.so format (lib prefix, simple name)" do
      it "derives symbol from libtoml.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/libtoml.so")).to eq("tree_sitter_toml")
      end

      it "derives symbol from libjson.so" do
        expect(described_class.derive_symbol_from_path("/usr/lib/libjson.so")).to eq("tree_sitter_json")
      end
    end

    context "with .dylib extension (macOS)" do
      it "derives symbol from libtree-sitter-toml.dylib" do
        expect(described_class.derive_symbol_from_path("/usr/local/lib/libtree-sitter-toml.dylib")).to eq("tree_sitter_toml")
      end

      it "derives symbol from toml.dylib" do
        expect(described_class.derive_symbol_from_path("/usr/local/lib/toml.dylib")).to eq("tree_sitter_toml")
      end
    end

    context "with .dll extension (Windows)" do
      it "derives symbol from libtree-sitter-toml.dll" do
        expect(described_class.derive_symbol_from_path("C:/libs/libtree-sitter-toml.dll")).to eq("tree_sitter_toml")
      end

      it "derives symbol from toml.dll" do
        expect(described_class.derive_symbol_from_path("C:/libs/toml.dll")).to eq("tree_sitter_toml")
      end
    end

    context "with versioned .so extension" do
      it "handles .so.0 extension" do
        expect(described_class.derive_symbol_from_path("/usr/lib/libtree-sitter-toml.so.0")).to eq("tree_sitter_toml")
      end

      it "handles .so.0.24 extension" do
        expect(described_class.derive_symbol_from_path("/usr/lib/libtree-sitter-toml.so.0.24")).to eq("tree_sitter_toml")
      end

      it "handles .so.0.24.3 extension" do
        expect(described_class.derive_symbol_from_path("/usr/lib/libtree-sitter-toml.so.0.24.3")).to eq("tree_sitter_toml")
      end
    end

    context "with various path formats" do
      it "handles absolute paths" do
        expect(described_class.derive_symbol_from_path("/usr/local/lib/libtree-sitter-toml.so")).to eq("tree_sitter_toml")
      end

      it "handles relative paths" do
        expect(described_class.derive_symbol_from_path("./lib/libtree-sitter-toml.so")).to eq("tree_sitter_toml")
      end

      it "handles paths with spaces" do
        expect(described_class.derive_symbol_from_path("/path with spaces/libtree-sitter-toml.so")).to eq("tree_sitter_toml")
      end

      it "handles just the filename" do
        expect(described_class.derive_symbol_from_path("libtree-sitter-toml.so")).to eq("tree_sitter_toml")
      end
    end
  end

  describe ".derive_language_name_from_path" do
    context "with nil path" do
      it "returns nil" do
        expect(described_class.derive_language_name_from_path(nil)).to be_nil
      end
    end

    context "with libtree-sitter-<lang>.so format" do
      it "derives language name from libtree-sitter-toml.so" do
        expect(described_class.derive_language_name_from_path("/usr/lib/libtree-sitter-toml.so")).to eq("toml")
      end

      it "derives language name from libtree-sitter-json.so" do
        expect(described_class.derive_language_name_from_path("/usr/lib/libtree-sitter-json.so")).to eq("json")
      end

      it "derives language name from libtree-sitter-ruby.so" do
        expect(described_class.derive_language_name_from_path("/usr/lib/libtree-sitter-ruby.so")).to eq("ruby")
      end

      it "handles language names with dashes (converted to underscores)" do
        expect(described_class.derive_language_name_from_path("/usr/lib/libtree-sitter-c-sharp.so")).to eq("c_sharp")
      end
    end

    context "with simple language name format" do
      it "derives language name from toml.so" do
        expect(described_class.derive_language_name_from_path("/usr/lib/toml.so")).to eq("toml")
      end

      it "derives language name from json.so" do
        expect(described_class.derive_language_name_from_path("/usr/lib/json.so")).to eq("json")
      end
    end

    context "with versioned .so extension" do
      it "handles versioned extensions" do
        expect(described_class.derive_language_name_from_path("/usr/lib/libtree-sitter-toml.so.0.24")).to eq("toml")
      end
    end

    context "with .dylib extension" do
      it "derives language name from .dylib files" do
        expect(described_class.derive_language_name_from_path("/usr/lib/libtree-sitter-python.dylib")).to eq("python")
      end
    end
  end

  describe ".derive_language_name_from_symbol" do
    context "with nil symbol" do
      it "returns nil" do
        expect(described_class.derive_language_name_from_symbol(nil)).to be_nil
      end
    end

    context "with tree_sitter_ prefixed symbol" do
      it "strips tree_sitter_ prefix from tree_sitter_toml" do
        expect(described_class.derive_language_name_from_symbol("tree_sitter_toml")).to eq("toml")
      end

      it "strips tree_sitter_ prefix from tree_sitter_json" do
        expect(described_class.derive_language_name_from_symbol("tree_sitter_json")).to eq("json")
      end

      it "strips tree_sitter_ prefix from tree_sitter_ruby" do
        expect(described_class.derive_language_name_from_symbol("tree_sitter_ruby")).to eq("ruby")
      end

      it "strips tree_sitter_ prefix from tree_sitter_c_sharp" do
        expect(described_class.derive_language_name_from_symbol("tree_sitter_c_sharp")).to eq("c_sharp")
      end

      it "strips tree_sitter_ prefix from tree_sitter_javascript" do
        expect(described_class.derive_language_name_from_symbol("tree_sitter_javascript")).to eq("javascript")
      end
    end

    context "with symbol that does not have tree_sitter_ prefix" do
      it "returns the symbol unchanged for 'toml'" do
        expect(described_class.derive_language_name_from_symbol("toml")).to eq("toml")
      end

      it "returns the symbol unchanged for 'json'" do
        expect(described_class.derive_language_name_from_symbol("json")).to eq("json")
      end

      it "returns the symbol unchanged for arbitrary strings" do
        expect(described_class.derive_language_name_from_symbol("some_other_symbol")).to eq("some_other_symbol")
      end
    end
  end

  describe "module_function behavior" do
    it "allows calling methods on the module directly" do
      expect(TreeHaver::LibraryPathUtils.derive_symbol_from_path("/lib/toml.so")).to eq("tree_sitter_toml")
    end

    it "methods are private when module is included (standard module_function behavior)" do
      klass = Class.new { include TreeHaver::LibraryPathUtils }
      instance = klass.new
      # module_function makes methods private when included
      expect(instance.private_methods).to include(:derive_symbol_from_path)
      # Can still call via send
      expect(instance.send(:derive_symbol_from_path, "/lib/toml.so")).to eq("tree_sitter_toml")
    end
  end

  describe "consistency between methods" do
    it "derive_language_name_from_path equals derive_language_name_from_symbol(derive_symbol_from_path)" do
      path = "/usr/lib/libtree-sitter-toml.so"
      symbol = described_class.derive_symbol_from_path(path)
      lang_from_path = described_class.derive_language_name_from_path(path)
      lang_from_symbol = described_class.derive_language_name_from_symbol(symbol)

      expect(lang_from_path).to eq(lang_from_symbol)
    end

    it "maintains consistency across different path formats" do
      paths = [
        "/usr/lib/libtree-sitter-toml.so",
        "/usr/lib/libtree_sitter_toml.so",
        "/usr/lib/tree-sitter-toml.so",
        "/usr/lib/tree_sitter_toml.so",
        "/usr/lib/toml.so",
      ]

      symbols = paths.map { |p| described_class.derive_symbol_from_path(p) }
      languages = paths.map { |p| described_class.derive_language_name_from_path(p) }

      expect(symbols.uniq).to eq(["tree_sitter_toml"])
      expect(languages.uniq).to eq(["toml"])
    end
  end
end

