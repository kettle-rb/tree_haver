# frozen_string_literal: true

# Shared test helpers for TreeHaver specs

module TreeHaverSpecHelpers
  # Creates a mock backend module with configurable behavior
  #
  # @param available [Boolean] whether the backend is available
  # @param capabilities [Hash] capability hash to return
  # @return [Module] a mock backend module
  def mock_backend(available: true, capabilities: {})
    Module.new do
      define_singleton_method(:available?) { available }
      define_singleton_method(:capabilities) { capabilities }

      const_set(:Language, Class.new do
        define_singleton_method(:from_library) do |path, symbol: nil, name: nil|
          double("Language", path: path, symbol: symbol)
        end

        define_singleton_method(:from_path) do |path|
          from_library(path)
        end
      end)

      const_set(:Parser, Class.new do
        attr_accessor :language

        def parse(source)
          mock_tree
        end

        def parse_string(old_tree, source)
          mock_tree
        end

        private

        def mock_tree
          double("Tree", root_node: mock_node)
        end

        def mock_node
          double(
            "Node",
            type: "document",
            each: [].each,
            start_point: double(row: 0, column: 0),
            end_point: double(row: 0, column: 0),
            start_byte: 0,
            end_byte: 0,
          )
        end
      end)
    end
  end

  # Stubs all backends as unavailable
  def stub_all_backends_unavailable
    allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(false)
    allow(TreeHaver::Backends::Rust).to receive(:available?).and_return(false)
    allow(TreeHaver::Backends::FFI).to receive(:available?).and_return(false)
    allow(TreeHaver::Backends::Java).to receive(:available?).and_return(false)
  end

  # Stubs a specific backend as available while others are unavailable
  #
  # @param backend [Symbol] :mri, :rust, :ffi, or :java
  def stub_only_backend_available(backend)
    stub_all_backends_unavailable
    case backend
    when :mri
      allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(true)
    when :rust
      allow(TreeHaver::Backends::Rust).to receive(:available?).and_return(true)
    when :ffi
      allow(TreeHaver::Backends::FFI).to receive(:available?).and_return(true)
    when :java
      allow(TreeHaver::Backends::Java).to receive(:available?).and_return(true)
    end
  end

  # Simulates JRuby environment
  def simulate_jruby
    stub_const("RUBY_ENGINE", "jruby")
  end

  # Simulates MRI environment
  def simulate_mri
    stub_const("RUBY_ENGINE", "ruby")
  end
end

RSpec.configure do |config|
  config.include TreeHaverSpecHelpers
end
