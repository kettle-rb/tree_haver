# frozen_string_literal: true

module TreeHaver
  # Base classes for backend implementation
  module Base
    autoload :Node, File.join(__dir__, "base", "node")
    autoload :Tree, File.join(__dir__, "base", "tree")
    autoload :Parser, File.join(__dir__, "base", "parser")
    autoload :Language, File.join(__dir__, "base", "language")
    autoload :Point, File.join(__dir__, "base", "point")
  end
end
