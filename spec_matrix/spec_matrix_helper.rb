# frozen_string_literal: true

# Minimal helper for backend compatibility matrix tests
# This helper intentionally does NOT load toml-rb or tree_sitter
# to allow testing backend combinations without MRI being pre-loaded

# External RSpec & related config
require "kettle/test/rspec"

# Config for development dependencies of this library
begin
  require "kettle-soup-cover"
  require "simplecov" if Kettle::Soup::Cover::DO_COV
rescue LoadError => error
  raise error unless error.message.include?("kettle")
end

# this library (but NOT toml-rb which loads tree_sitter)
require "tree_haver"

# Support files for matrix tests only
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Clear language cache before each test to prevent cross-test pollution
  config.before(:each) do
    TreeHaver::LanguageRegistry.clear_cache!
  end

  config.after(:each) do
    TreeHaver::LanguageRegistry.clear_cache!
    TreeHaver.reset_backend!(to: :auto)
  end
end
