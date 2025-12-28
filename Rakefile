# frozen_string_literal: true

# kettle-dev Rakefile v1.2.4 - 2025-11-28
# Ruby 2.3 (Safe Navigation) or higher required
#
# MIT License (see License.txt)
#
# Copyright (c) 2025 Peter H. Boling (galtzo.com)
#
# Expected to work in any project that uses Bundler.
#
# Sets up tasks for appraisal, floss_funding, rspec, minitest, rubocop, reek, yard, and stone_checksums.
#
# rake appraisal:install                      # Install Appraisal gemfiles (initial setup...
# rake appraisal:reset                        # Delete Appraisal lockfiles (gemfiles/*.gemfile.lock)
# rake appraisal:update                       # Update Appraisal gemfiles and run RuboCop...
# rake bench                                  # Run all benchmarks (alias for bench:run)
# rake bench:list                             # List available benchmark scripts
# rake bench:run                              # Run all benchmark scripts (skips on CI)
# rake build:generate_checksums               # Generate both SHA256 & SHA512 checksums i...
# rake bundle:audit:check                     # Checks the Gemfile.lock for insecure depe...
# rake bundle:audit:update                    # Updates the bundler-audit vulnerability d...
# rake ci:act[opt]                            # Run 'act' with a selected workflow
# rake coverage                               # Run specs w/ coverage and open results in...
# rake default                                # Default tasks aggregator
# rake install                                # Build and install kettle-dev-1.0.0.gem in...
# rake install:local                          # Build and install kettle-dev-1.0.0.gem in...
# rake kettle:dev:install                     # Install kettle-dev GitHub automation and ...
# rake kettle:dev:template                    # Template kettle-dev files into the curren...
# rake reek                                   # Check for code smells
# rake reek:update                            # Run reek and store the output into the RE...
# rake release[remote]                        # Create tag v1.0.0 and build and push kett...
# rake rubocop_gradual                        # Run RuboCop Gradual
# rake rubocop_gradual:autocorrect            # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual:autocorrect_all        # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual:check                  # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual:force_update           # Run RuboCop Gradual to force update the l...
# rake rubocop_gradual_debug                  # Run RuboCop Gradual
# rake rubocop_gradual_debug:autocorrect      # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual_debug:autocorrect_all  # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual_debug:check            # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual_debug:force_update     # Run RuboCop Gradual to force update the l...
# rake spec                                   # Run RSpec code examples
# rake test                                   # Run tests
# rake yard                                   # Generate YARD Documentation
#

require "bundler/gem_tasks" if !Dir[File.join(__dir__, "*.gemspec")].empty?

# Define a base default task early so other files can enhance it.
desc "Default tasks aggregator"
task :default do
  puts "Default task complete."
end

# External gems that define tasks - add here!
require "kettle/dev"

### RELEASE TASKS
# Setup stone_checksums
begin
  require "stone_checksums"
rescue LoadError
  desc("(stub) build:generate_checksums is unavailable")
  task("build:generate_checksums") do
    warn("NOTE: stone_checksums isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
  end
end

### SPEC TASKS
# Run FFI specs first (before the collision of MRI+FFI backends pollutes the environment),
# then run remaining specs. This ensures FFI tests get a clean environment
# while still validating that BackendConflict protection works.
#
# For coverage aggregation with SimpleCov merging:
# - Each task uses a unique K_SOUP_COV_COMMAND_NAME so SimpleCov tracks them separately
# - K_SOUP_COV_USE_MERGING=true must be set in .envrc for results to merge
# - K_SOUP_COV_MERGE_TIMEOUT should be set long enough for all tasks to complete
begin
  require "rspec/core/rake_task"

  # FFI specs run first in a clean environment
  desc("Run FFI backend specs first (before MRI loads)")
  RSpec::Core::RakeTask.new(:ffi_specs) do |t|
    t.pattern = "./spec/**/*_spec.rb"
    t.rspec_opts = "--tag ffi"
  end
  # Set unique command name at execution time for SimpleCov merging
  desc("Set SimpleCov command name for FFI specs")
  task(:set_ffi_command_name) do
    ENV["K_SOUP_COV_COMMAND_NAME"] = "FFI Specs"
  end
  Rake::Task[:ffi_specs].enhance([:set_ffi_command_name])

  # Matrix checks will run in between FFI and MRI
  desc("Run Backend Matrix Specs")
  RSpec::Core::RakeTask.new(:backend_matrix_specs) do |t|
    t.pattern = "./spec_matrix/**/*_spec.rb"
  end
  desc("Set SimpleCov command name for backend matrix specs")
  task(:set_matrix_command_name) do
    ENV["K_SOUP_COV_COMMAND_NAME"] = "Backend Matrix Specs"
  end
  Rake::Task[:backend_matrix_specs].enhance([:set_matrix_command_name])

  # All other specs run after FFI specs
  desc("Run non-FFI specs (after FFI specs have run)")
  RSpec::Core::RakeTask.new(:remaining_specs) do |t|
    t.pattern = "./spec/**/*_spec.rb"
    t.rspec_opts = "--tag ~ffi"
  end
  desc("Set SimpleCov command name for remaining specs")
  task(:set_remaining_command_name) do
    ENV["K_SOUP_COV_COMMAND_NAME"] = "Remaining Specs"
  end
  Rake::Task[:remaining_specs].enhance([:set_remaining_command_name])

  # Final task to run all specs (for spec task, runs in single process for final coverage merge)
  desc("Run all specs in one process (no FFI isolation)")
  RSpec::Core::RakeTask.new(:all_specs) do |t|
    t.pattern = "spec/**{,/*/**}/*_spec.rb"
  end
  desc("Set SimpleCov command name for all specs")
  task(:set_all_command_name) do
    ENV["K_SOUP_COV_COMMAND_NAME"] = "All Specs"
  end
  Rake::Task[:all_specs].enhance([:set_all_command_name])

  # Override the default spec task to run in sequence
  # NOTE: We do NOT include :all_specs here because ffi_specs + remaining_specs already
  # cover all specs. Including all_specs would cause duplicated test runs.
  Rake::Task[:spec].clear if Rake::Task.task_defined?(:spec)
  desc("Run specs with FFI tests first, then backend matrix, then remaining tests")
  task(spec: [:ffi_specs, :backend_matrix_specs, :remaining_specs]) # rubocop:disable Rake/DuplicateTask:
rescue LoadError
  desc("(stub) spec is unavailable")
  task(:spec) do # rubocop:disable Rake/DuplicateTask:
    warn("NOTE: rspec isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
  end
end
