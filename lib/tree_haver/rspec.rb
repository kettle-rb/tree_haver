# frozen_string_literal: true

# TreeHaver RSpec Integration
#
# This file provides RSpec helpers and configuration for testing
# code that uses TreeHaver. Require this in your spec_helper.rb:
#
#   require "tree_haver/rspec"
#
# This will load:
# - Dependency tags for conditional test execution
# - (Future) Additional test helpers as needed
#
# @example spec_helper.rb
#   require "tree_haver/rspec"
#
#   RSpec.configure do |config|
#     # Your additional configuration...
#   end
#
# @see TreeHaver::RSpec::DependencyTags

require_relative "rspec/dependency_tags"
