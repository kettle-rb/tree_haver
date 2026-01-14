# frozen_string_literal: true

module TreeHaver
  # Version information for TreeHaver
  #
  # This module contains version constants following Semantic Versioning 2.0.0.
  #
  # @see https://semver.org/ Semantic Versioning
  module Version
    # Current version of the tree_haver gem
    #
    # @return [String] the version string
    VERSION = "5.0.2"
  end

  # Traditional location for VERSION constant
  #
  # @return [String] the version string
  VERSION = Version::VERSION
end
