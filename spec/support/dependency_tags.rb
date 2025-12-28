# frozen_string_literal: true

# Load shared dependency tags from lib/tree_haver/rspec/dependency_tags.rb
#
# This file follows the standard spec/support/ convention. The actual
# implementation is in the lib directory so it can be shared across all
# gems in the TreeHaver/ast-merge family.
#
# Other gems can simply:
#   require "tree_haver/rspec"
#
# @see TreeHaver::RSpec::DependencyTags

require "tree_haver/rspec"

# Alias for convenience in existing specs
TreeHaverDependencies = TreeHaver::RSpec::DependencyTags
