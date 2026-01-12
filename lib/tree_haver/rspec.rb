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
# - TestableNode for creating mock nodes in tests
#
# @example spec_helper.rb
#   require "tree_haver/rspec"
#
#   RSpec.configure do |config|
#     # Your additional configuration...
#   end
#
# @example Using TestableNode
#   node = TestableNode.create(
#     type: :heading,
#     text: "## My Heading",
#     start_line: 1
#   )
#   expect(node.type).to eq("heading")
#
# @see TreeHaver::RSpec::DependencyTags
# @see TreeHaver::RSpec::TestableNode

require_relative "rspec/dependency_tags"
require_relative "rspec/testable_node"
