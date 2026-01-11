# TreeHaver Wrapping/Unwrapping Architecture

## Principle of Least Surprise (PoLS)

TreeHaver follows a **single responsibility** pattern for object wrapping:

- **TreeHaver::Parser** (top level) handles ALL wrapping and unwrapping
- **Backends** work exclusively with raw backend objects
- **User-facing API** uses only TreeHaver wrapper classes

This ensures:
- Consistency across all backends
- Predictable behavior (PoLS)
- Single place for complexity
- Simple backend implementations
- Easy debugging

## Architecture Overview

```
User Code → TreeHaver::Parser → Backend → Raw Objects
            ↑ wraps/unwraps ↑    ↓ raw in/out ↓
User Code ← TreeHaver::Tree ←────┘
            TreeHaver::Node
```

## Inheritance Hierarchy

### Base Classes

Located in `lib/tree_haver/base/`:

- `TreeHaver::Base::Parser` - Base class for backend Parser implementations
- `TreeHaver::Base::Tree` - Base class for backend Tree implementations  
- `TreeHaver::Base::Node` - Base class for backend Node implementations (provides Position API)

### Top-Level Wrappers

Located in `lib/tree_haver/`:

- `TreeHaver::Parser` - Inherits from `Base::Parser`, handles wrapping/unwrapping
- `TreeHaver::Tree` - Inherits from `Base::Tree`, wraps tree-sitter backend trees
- `TreeHaver::Node` - Inherits from `Base::Node`, wraps tree-sitter backend nodes

### Backend-Specific Classes

Pure-Ruby backends define their own complete implementations:

- `Backends::Citrus::{Parser,Tree,Node}` - Inherits from `Base::*`
- `Backends::Parslet::{Parser,Tree,Node}` - Inherits from `Base::*`
- `Backends::Prism::{Parser,Tree,Node}` - Inherits from `Base::*`
- `Backends::Psych::{Parser,Tree,Node}` - Inherits from `Base::*`

Tree-sitter backends (MRI, Rust, FFI, Java) do NOT define their own Tree/Node classes. They return raw backend objects that `TreeHaver::Tree` and `TreeHaver::Node` wrap.

## Language Objects

### Wrapping Contract

**Input to `TreeHaver::Parser#language=`:**
- User passes: `TreeHaver::Backends::*::Language` wrapper

**TreeHaver::Parser unwraps:**
- Calls `unwrap_language(lang)` helper method
- Verifies backend compatibility via `lang.backend`
- Attempts reload if backend mismatch detected

**Backend receives (after unwrapping):**

| Backend | Receives |
|---------|----------|
| MRI | `::TreeSitter::Language` (via `to_language` or `inner_language`) |
| Rust | `String` (language name via `name`) |
| FFI | `TreeHaver::Backends::FFI::Language` wrapper (needs `to_ptr`) |
| Java | Java Language object (via `impl`) |
| Citrus | `TreeHaver::Backends::Citrus::Language` wrapper |
| Parslet | `TreeHaver::Backends::Parslet::Language` wrapper |
| Prism | `TreeHaver::Backends::Prism::Language` wrapper |
| Psych | `TreeHaver::Backends::Psych::Language` wrapper |

### Unwrapping Logic

Located in `TreeHaver::Parser#unwrap_language`:

```ruby
def unwrap_language(lang)
  # Verify backend compatibility
  if lang.respond_to?(:backend)
    current_backend = backend
    if lang.backend != current_backend && current_backend != :auto
      # Backend mismatch - attempt reload
      reloaded = try_reload_language_for_backend(lang, current_backend)
      lang = reloaded if reloaded
    end
  end

  # Unwrap based on backend type
  case lang.backend
  when :mri
    lang.to_language || lang.inner_language
  when :rust
    lang.name
  when :ffi
    lang  # FFI needs wrapper for to_ptr
  when :java
    lang.impl
  when :citrus, :parslet, :prism, :psych
    lang  # These backends accept the Language wrapper
  else
    # Unknown backend - try generic unwrapping
    lang
  end
end
```

**Special Case: FFI Backend**
- FFI is unique: it needs the wrapped `Language` object to call `to_ptr`
- The FFI backend's `language=` expects the wrapper, not an unwrapped pointer

**Backend Attribute Requirement**
- All TreeHaver Language wrappers have a `backend` attribute
- This enables backend compatibility checking
- Passing a raw backend object (without `backend` attribute) raises an error

## Tree Objects

### Wrapping Contract

**Parsing (initial):**
1. User calls `parser.parse(source)`
2. TreeHaver::Parser calls `backend.parse(source)`
3. Backend returns raw tree (TreeSitter::Tree, TreeStump::Tree, etc.)
4. TreeHaver::Parser wraps: `Tree.new(raw_tree, source: source)`
5. User receives `TreeHaver::Tree`

**Incremental Parsing:**
1. User calls `parser.parse_string(old_tree, source)`
2. TreeHaver::Parser unwraps `old_tree.inner_tree`
3. TreeHaver::Parser calls `backend.parse_string(raw_old_tree, source)`
4. Backend receives raw tree, returns raw tree
5. TreeHaver::Parser wraps: `Tree.new(raw_tree, source: source)`
6. User receives `TreeHaver::Tree`

### Unwrapping Logic

Located in `TreeHaver::Parser#parse_string`:

```ruby
old_impl = if old_tree.respond_to?(:inner_tree)
  old_tree.inner_tree
elsif old_tree.respond_to?(:instance_variable_get)
  # Fallback for compatibility
  old_tree.instance_variable_get(:@inner_tree) ||
    old_tree.instance_variable_get(:@impl) ||
    old_tree
else
  old_tree
end
```

**Backend Expectations:**
- All backends receive raw backend tree objects (or nil)
- All backends return raw backend tree objects
- NO backend should do its own unwrapping (TreeHaver::Parser handles it)

## Node Objects

### Wrapping Contract

**Node Creation:**
1. Backend tree has `root_node` method returning raw backend node
2. `TreeHaver::Tree#root_node` wraps: `Node.new(raw_node, source: @source)`
3. `TreeHaver::Node` methods (like `child`, `children`) wrap returned nodes
4. User always works with `TreeHaver::Node` objects

**No Unwrapping Needed:**
- Nodes are never passed TO backends
- Nodes are only created FROM backend nodes
- One-way wrapping only

## Backend Compliance Checklist

### Language Handling
- `language=` accepts raw unwrapped object (or wrapper for Citrus/Parslet/Prism/Psych/FFI)
- `language=` returns the object it received (for consistency)
- No unwrapping logic in backend (TreeHaver::Parser does it)

### Tree Handling (parse)
- `parse(source)` returns raw backend tree
- No wrapping in `parse` (TreeHaver::Parser wraps result)

### Tree Handling (parse_string)
- `parse_string(old_tree, source)` expects raw tree (already unwrapped)
- `parse_string` returns raw backend tree
- No unwrapping in `parse_string` (TreeHaver::Parser does it)
- No wrapping in `parse_string` (TreeHaver::Parser wraps result)

## Current Backend Status

| Backend | Language | parse | parse_string | Notes |
|---------|----------|-------|--------------|-------|
| MRI     | ✓        | ✓     | ✓            | C extension, MRI only |
| Rust    | ✓        | ✓     | ✓            | Rust via magnus, MRI only |
| FFI     | ✓*       | ✓     | N/A          | *Receives wrapper (needs `to_ptr`) |
| Java    | ✓        | ✓     | ✓            | JRuby only |
| Citrus  | ✓        | ✓     | ✓            | Pure Ruby PEG |
| Parslet | ✓        | ✓     | ✓            | Pure Ruby PEG |
| Prism   | ✓        | ✓     | ✓            | Ruby parser (stdlib) |
| Psych   | ✓        | ✓     | ✓            | YAML parser (stdlib) |

## Benefits of This Architecture

1. **Single Responsibility** - Only TreeHaver::Parser knows about wrapping
2. **Consistency** - All backends follow the same pattern
3. **Simplicity** - Backends don't need to handle wrapper types
4. **Testability** - Easy to mock at boundaries
5. **Maintainability** - Changes to wrapping logic are centralized
6. **PoLS** - Users never see backend-specific wrapper types
7. **Performance** - No double wrapping/unwrapping

## Anti-Patterns to Avoid

**Don't unwrap in backends:**
```ruby
# BAD - backend doing unwrapping
def language=(lang)
  inner = lang.respond_to?(:inner_language) ? lang.inner_language : lang
  @parser.language = inner
end
```

**Let TreeHaver::Parser unwrap:**
```ruby
# GOOD - backend expects unwrapped (or wrapper for some backends)
def language=(lang)
  # lang is already processed by TreeHaver::Parser
  @parser.language = lang
  lang
end
```

**Don't wrap in backends:**
```ruby
# BAD - backend doing wrapping
def parse(source)
  raw_tree = @parser.parse(source)
  TreeHaver::Tree.new(raw_tree, source: source)  # Wrong!
end
```

**Return raw objects:**
```ruby
# GOOD - return raw, TreeHaver::Parser wraps
def parse(source)
  @parser.parse(source)  # Return raw tree
end
```

## Testing Strategy

### Unit Tests (Backend)
- Pass raw objects to backend methods
- Verify backend returns raw objects
- No TreeHaver wrapper types in backend tests

### Integration Tests (TreeHaver::Parser)
- Pass wrapped objects to TreeHaver::Parser
- Verify TreeHaver::Parser unwraps before calling backend
- Verify TreeHaver::Parser wraps backend results
- Verify users receive TreeHaver wrapper types

### Contract Tests
- Verify all backends follow the same contract
- Test with different wrapper types
- Test with raw objects (should pass through)
- Test nil handling
