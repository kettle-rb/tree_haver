# frozen_string_literal: true

module TreeHaver
  module Base
    # Base class for backend Parser implementations
    # Used by wrapper backends (Commonmarker, Markly, etc.)
    # Raw backends (MRI/Rust) do not inherit from this.
    class Parser
      attr_accessor :language

      def initialize
        @language = nil
      end

      def parse(source)
        raise NotImplementedError
      end

      def parse_string(_old_tree, source)
        parse(source)
      end
    end
  end
end

