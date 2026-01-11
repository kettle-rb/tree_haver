# Position API

TreeHaver provides a unified Position API across all backends, enabling consistent access to node position information regardless of the underlying parser.

## Methods

All Node classes implement the following position methods:

### `start_line`

Returns the 1-based line number where the node starts.

- For backends with 0-based rows: `start_point.row + 1`
- For backends with native 1-based lines: uses the backend's value directly

### `end_line`

Returns the 1-based line number where the node ends.

- For backends with 0-based rows: `end_point.row + 1`
- For backends with native 1-based lines: uses the backend's value directly

### `source_position`

Returns a position hash with 1-based lines and 0-based columns:

```ruby
{start_line:, end_line:, start_column:, end_column:}
```

- Lines are 1-based (human-readable)
- Columns are 0-based (matches tree-sitter convention)
- Compatible with `*-merge` gems' `FileAnalysisBase` expectations

### `first_child`

Returns `children.first` (or `child(0)` for some backends).

Convenience method for node iteration.

---

## Backend Support

### TreeHaver::Base::Node

The base class defines the Position API contract. All position methods (`start_line`, `end_line`, `source_position`, `first_child`) are implemented here with sensible defaults that handle both Hash and Object-style point representations.

All backend Node classes inherit from `Base::Node`.

### TreeHaver::Node (Tree-sitter Backends)

Inherits from `Base::Node`. Wraps raw `::TreeSitter::Node` objects from:

- Tree-sitter MRI backend
- Tree-sitter FFI backend
- Tree-sitter Java backend
- Tree-sitter Rust backend

### Commonmarker Backend

`TreeHaver::Backends::Commonmarker::Node` inherits from `Base::Node`.

Overrides position methods to use Commonmarker's `sourcepos` array, which provides 1-based line numbers directly.

### Markly Backend

`TreeHaver::Backends::Markly::Node` inherits from `Base::Node`.

Overrides position methods to use Markly's `source_position` hash, which provides 1-based line numbers directly.

### Prism Backend

`TreeHaver::Backends::Prism::Node` inherits from `Base::Node`.

Overrides position methods to use Prism's `Location` object, which provides 1-based line numbers directly.

### Psych Backend

`TreeHaver::Backends::Psych::Node` inherits from `Base::Node`.

Uses the inherited implementation, which calculates from `start_point.row + 1` and `end_point.row + 1`.

### Citrus Backend

`TreeHaver::Backends::Citrus::Node` inherits from `Base::Node`.

Uses the inherited implementation, which handles both Hash (`start_point[:row]`) and Object (`start_point.row`) point representations.

---

## Usage Example

```ruby
require "tree_haver/backends/psych"

parser = TreeHaver::Backends::Psych::Parser.new
parser.language = TreeHaver::Backends::Psych::Language.yaml
tree = parser.parse("foo: bar")
node = tree.root_node

node.start_line      # => 1
node.end_line        # => 2
node.source_position # => {start_line: 1, end_line: 2, start_column: 0, end_column: 0}
node.first_child     # => <first child node>
```

---

## Implementation Notes

### Base Class with Overrides

The Position API uses inheritance from `TreeHaver::Base::Node`:

1. **Shared Implementation** - `Base::Node` provides default implementations that handle both Hash and Object point representations
2. **Backend Overrides** - Backends with native 1-based line numbers (Commonmarker, Markly, Prism) override the methods to use their optimized representations
3. **Automatic Inheritance** - Backends without overrides (Psych, Citrus, tree-sitter) inherit the working defaults

### Conversion Formulas

| Backend Type | Line Calculation |
|--------------|------------------|
| tree-sitter, Psych, Citrus | `start_point.row + 1` (inherited from Base::Node) |
| Commonmarker, Markly, Prism | Native 1-based value (overridden methods) |

### Language-Agnostic

Position information is a property of the source text, not the language. These methods work identically for:

- Ruby (Prism backend)
- Markdown (Commonmarker, Markly backends)
- YAML (Psych backend)
- TOML (Citrus backend via toml-rb)
- JSON (tree-sitter backends)
