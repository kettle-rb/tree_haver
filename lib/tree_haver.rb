# frozen_string_literal: true

# External gems
require "version_gem"

# This gem
require_relative "tree_haver/version"

module TreeHaver
  # Base error class for TreeHaver
  class Error < StandardError; end
end

TreeHaver::Version.class_eval do
  extend VersionGem::Basic
end
