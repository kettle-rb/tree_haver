# frozen_string_literal: true

# FFI-only spec helper
# This helper ensures FFI tests run in isolation without MRI backend loaded.
#
# Usage: Run FFI tests in isolation with:
#   bin/rspec-ffi
#
# HOW ISOLATION WORKS:
# 1. bin/rspec-ffi sets ENV["TREE_HAVER_BACKEND"] = "ffi" before exec
# 2. This env var is inherited by the rspec process
# 3. When dependency_tags.rb loads, it sees TREE_HAVER_BACKEND=ffi
# 4. It looks up BLOCKED_BY[:ffi] = [:mri] and adds :mri to blocked_backends
# 5. This prevents mri_backend_available? from being called (which loads MRI)
# 6. THEN this file loads and verifies MRI wasn't loaded
#
# The --tag ffi_backend_only provides additional protection and sets
# isolated_test_mode which skips grammar availability checks that might
# also trigger MRI loading.

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

warn "✓ FFI-only test mode: MRI backend is NOT loaded"
