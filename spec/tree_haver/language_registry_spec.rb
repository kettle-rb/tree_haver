# frozen_string_literal: true

RSpec.describe TreeHaver::LanguageRegistry do
  let(:registry) { described_class }

  before do
    registry.clear_all!
  end

  after do
    registry.clear_all!
  end

  describe ".register" do
    it "registers a language with path and symbol" do
      registry.register(:toml, path: "/path/to/lib.so", symbol: "tree_sitter_toml")
      entry = registry.registered(:toml)
      expect(entry).to eq({path: "/path/to/lib.so", symbol: "tree_sitter_toml"})
    end

    it "registers a language with path only" do
      registry.register(:json, path: "/path/to/json.so")
      entry = registry.registered(:json)
      expect(entry).to eq({path: "/path/to/json.so", symbol: nil})
    end

    it "accepts string names and converts to symbol" do
      registry.register("yaml", path: "/path/to/yaml.so")
      expect(registry.registered(:yaml)).not_to be_nil
      expect(registry.registered("yaml")).not_to be_nil
    end

    it "overwrites existing registration" do
      registry.register(:toml, path: "/old/path.so")
      registry.register(:toml, path: "/new/path.so", symbol: "new_symbol")
      entry = registry.registered(:toml)
      expect(entry[:path]).to eq("/new/path.so")
      expect(entry[:symbol]).to eq("new_symbol")
    end
  end

  describe ".unregister" do
    it "removes a registered language" do
      registry.register(:toml, path: "/path/lib.so")
      expect(registry.registered(:toml)).not_to be_nil
      registry.unregister(:toml)
      expect(registry.registered(:toml)).to be_nil
    end

    it "handles unregistering non-existent language" do
      expect { registry.unregister(:nonexistent) }.not_to raise_error
    end

    it "accepts string names" do
      registry.register(:toml, path: "/path/lib.so")
      registry.unregister("toml")
      expect(registry.registered(:toml)).to be_nil
    end
  end

  describe ".registered" do
    it "returns nil for unregistered language" do
      expect(registry.registered(:unknown)).to be_nil
    end

    it "returns registration hash for registered language" do
      registry.register(:toml, path: "/lib.so", symbol: "ts_toml")
      entry = registry.registered(:toml)
      expect(entry).to be_a(Hash)
      expect(entry).to have_key(:path)
      expect(entry).to have_key(:symbol)
    end
  end

  describe ".clear_registrations!" do
    it "removes all registrations" do
      registry.register(:toml, path: "/a.so")
      registry.register(:json, path: "/b.so")
      registry.clear_registrations!
      expect(registry.registered(:toml)).to be_nil
      expect(registry.registered(:json)).to be_nil
    end

    it "does not affect cache" do
      key = ["test_key"]
      registry.fetch(key) { "cached_value" }
      registry.clear_registrations!
      # Cache should still have the value
      result = registry.fetch(key) { "new_value" }
      expect(result).to eq("cached_value")
    end
  end

  describe ".fetch" do
    it "caches and returns value on first call" do
      call_count = 0
      key = ["/path.so", "symbol", "name"]
      result = registry.fetch(key) do
        call_count += 1
        "computed_value"
      end
      expect(result).to eq("computed_value")
      expect(call_count).to eq(1)
    end

    it "returns cached value without calling block on subsequent calls" do
      call_count = 0
      key = ["/path.so", "symbol", "name"]
      registry.fetch(key) {
        call_count += 1
        "first"
      }
      result = registry.fetch(key) {
        call_count += 1
        "second"
      }
      expect(result).to eq("first")
      expect(call_count).to eq(1)
    end

    it "handles different keys independently" do
      key1 = ["/path1.so", "sym1", "name1"]
      key2 = ["/path2.so", "sym2", "name2"]
      registry.fetch(key1) { "value1" }
      registry.fetch(key2) { "value2" }
      expect(registry.fetch(key1) { "x" }).to eq("value1")
      expect(registry.fetch(key2) { "x" }).to eq("value2")
    end

    it "uses array equality for cache keys" do
      key1 = ["/path.so", "symbol", "name"]
      key2 = ["/path.so", "symbol", "name"]
      registry.fetch(key1) { "cached" }
      result = registry.fetch(key2) { "not_cached" }
      expect(result).to eq("cached")
    end
  end

  describe ".clear_cache!" do
    it "removes all cached values" do
      registry.fetch(["key1"]) { "value1" }
      registry.fetch(["key2"]) { "value2" }
      registry.clear_cache!
      # After clearing, block should be called again
      call_count = 0
      registry.fetch(["key1"]) {
        call_count += 1
        "new"
      }
      expect(call_count).to eq(1)
    end

    it "does not affect registrations" do
      registry.register(:toml, path: "/lib.so")
      registry.clear_cache!
      expect(registry.registered(:toml)).not_to be_nil
    end
  end

  describe ".clear_all!" do
    it "clears both registrations and cache" do
      registry.register(:toml, path: "/lib.so")
      registry.fetch(["cache_key"]) { "cached" }
      registry.clear_all!
      expect(registry.registered(:toml)).to be_nil
      call_count = 0
      registry.fetch(["cache_key"]) {
        call_count += 1
        "new"
      }
      expect(call_count).to eq(1)
    end
  end

  describe "thread safety" do
    it "handles concurrent registrations safely" do
      threads = 10.times.map do |i|
        Thread.new do
          100.times do |j|
            registry.register(:"lang_#{i}_#{j}", path: "/path/#{i}/#{j}.so")
          end
        end
      end
      threads.each(&:join)
      # Should have registered 1000 languages without errors
      expect(registry.registered(:lang_5_50)).not_to be_nil
    end

    it "handles concurrent fetches safely" do
      threads = 10.times.map do |i|
        Thread.new do
          100.times do |j|
            registry.fetch(["key", i, j]) { "value_#{i}_#{j}" }
          end
        end
      end
      threads.each(&:join)
      # All fetches should have succeeded
      expect(registry.fetch(["key", 5, 50]) { "x" }).to eq("value_5_50")
    end
  end
end
