# frozen_string_literal: true

# FFI-only spec helper
# This helper ensures FFI tests run in isolation without MRI backend loaded.
#
# Usage: Run FFI tests in isolation with:
#   bin/rspec-ffi
#
# NOTE: spec_thin_helper is already loaded by .rspec before this file runs.
# The FFI backend is lazily loaded, so requiring TreeHaver does not
# pollute the environment. However, FFI still cannot coexist with MRI
# in the same process due to libtree-sitter symbol conflicts.

# Verify MRI is not already loaded
if defined?(TreeSitter::Parser)
  raise "MRI backend (ruby_tree_sitter) is already loaded! " \
    "FFI tests must run in isolation. " \
    "Use: bin/rspec-ffi"
end

# Force FFI backend selection
TreeHaver.backend = :ffi

# Verify FFI is available
unless TreeHaver::Backends::FFI.available?
  raise "FFI gem is not available!"
end

# FFI-specific RSpec configuration
RSpec.configure do |config|
  config.before do
    # Verify MRI is still not loaded during tests
    if defined?(TreeSitter::Parser)
      raise "MRI backend was loaded during test - FFI tests cannot continue!"
    end
  end

  config.after do
    # Stay on FFI backend
    TreeHaver.reset_backend!(to: :ffi)
  end
end

puts "✓ FFI-only test mode: MRI backend is NOT loaded"
