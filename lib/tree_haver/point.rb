# frozen_string_literal: true

module TreeHaver
  # Point class that works as both a Hash and an object with row/column accessors
  #
  # This provides compatibility with code expecting either:
  # - Hash access: point[:row], point[:column]
  # - Method access: point.row, point.column
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
  class Point
    attr_reader :row, :column

    # Create a new Point
    #
    # @param row [Integer] the row (line) number, 0-indexed
    # @param column [Integer] the column number, 0-indexed
    def initialize(row, column)
      @row = row
      @column = column
    end

    # Hash-like access for compatibility
    #
    # @param key [Symbol, String] :row or :column
    # @return [Integer, nil] the value or nil if key not recognized
    def [](key)
      case key
      when :row, "row" then @row
      when :column, "column" then @column
      end
    end

    # Convert to a hash
    #
    # @return [Hash{Symbol => Integer}]
    def to_h
      {row: @row, column: @column}
    end

    # String representation
    #
    # @return [String]
    def to_s
      "(#{@row}, #{@column})"
    end

    # Inspect representation
    #
    # @return [String]
    def inspect
      "#<TreeHaver::Point row=#{@row} column=#{@column}>"
    end
  end
end

