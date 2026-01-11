# frozen_string_literal: true

# Master loader for all TreeHaver shared examples
#
# This file loads all shared example files so they can be used in any spec.
# Require this file in your spec_helper or directly in specs that need it.
#
# @example In spec_helper.rb
#   require_relative "support/shared_examples"
#
# @example In a specific spec
#   require_relative "../support/shared_examples"

# Load all shared example files
Dir[File.join(__dir__, "shared_examples", "*.rb")].each do |file|
  require file
end

