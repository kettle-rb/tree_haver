# frozen_string_literal: true

# External gems/libs
require "securerandom"

# External RSpec & related config
require "kettle/test/rspec"

# Internal ENV config
require_relative "config/debug"

# Config for development dependencies of this library
# i.e., not configured by this library
#
# Simplecov & related config (must run BEFORE any other requires)
# NOTE: Gemfiles for older rubies won't have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  require "simplecov" if Kettle::Soup::Cover::DO_COV # `.simplecov` is run here!
rescue LoadError => error
  # check the error message and re-raise when unexpected
  raise error unless error.message.include?("kettle")
end

# this library
require "tree_haver"

# Support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.before do
    # Speed up polling loops
    allow(described_class).to receive(:sleep) unless described_class.nil?
  end

  # Clear language cache before each test to prevent cross-test pollution
  # This is critical because cached Language objects hold backend-specific pointers
  # that become invalid when the backend changes
  config.before do
    TreeHaver::LanguageRegistry.clear_cache!
    # NOTE: Do NOT reset backends_used! The tracking is essential for backend_protect
    # to prevent FFI+MRI conflicts that cause segfaults
  end

  config.after do
    TreeHaver::LanguageRegistry.clear_cache!
    TreeHaver.reset_backend!(to: :auto)
    # NOTE: Do NOT reset backends_used! Once a backend is used, it stays recorded
  end
end
