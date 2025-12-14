# frozen_string_literal: true

RSpec.describe TreeHaver::Backends::Java do
  let(:backend) { described_class }

  describe "::available?" do
    it "returns true or false depending on JRuby and classpath" do
      expect([true, false]).to include(backend.available?)
    end
  end

  describe "::capabilities" do
    it "is empty hash when unavailable; includes backend when available" do
      caps = backend.capabilities
      if backend.available?
        expect(caps).to include(:backend)
        expect(caps[:backend]).to eq(:java)
      else
        expect(caps).to eq({})
      end
    end
  end

  describe "forcing :java backend selection" do
    it "raises NotAvailable from facade when Java backend cannot be used" do
      stub_env("TREE_HAVER_BACKEND" => "java")
      # Reset memoized selection to ensure spec isolation
      TreeHaver.reset_backend!(to: :java)
      if backend.available?
        # Currently unimplemented; should still raise NotAvailable when called
        expect {
          TreeHaver::Language.from_path("/nonexistent/path/to/libtree-sitter-toml.so")
        }.to raise_error(TreeHaver::NotAvailable)
      else
        expect(TreeHaver.backend).to eq(:java)
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::Java)
        expect {
          TreeHaver::Language.from_path("/nonexistent/path/to/libtree-sitter-toml.so")
        }.to raise_error(TreeHaver::NotAvailable)
      end
    end
  end
end
