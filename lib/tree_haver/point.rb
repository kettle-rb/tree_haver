# frozen_string_literal: true

module TreeHaver
  # Point class that works as both a Hash and an object with row/column accessors
  #
  # This provides compatibility with code expecting either:
  # - Hash access: point[:row], point[:column]
  # - Method access: point.row, point.column
  #
  # TreeHaver::Point is an alias for TreeHaver::Base::Point, which is a Struct
  # providing all the necessary functionality.
  #
  # @example Method access
  #   point = TreeHaver::Point.new(5, 10)
  #   point.row    # => 5
  #   point.column # => 10
  #
  # @example Hash-like access
  #   point[:row]    # => 5
  #   point[:column] # => 10
  #
  # @example Converting to hash
  #   point.to_h # => {row: 5, column: 10}
  #
  # @see Base::Point The underlying Struct implementation
  Point = Base::Point
end
