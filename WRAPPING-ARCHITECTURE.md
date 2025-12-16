# TreeHaver Wrapping/Unwrapping Architecture

## Principle of Least Surprise (PoLS)

TreeHaver follows a **single responsibility** pattern for object wrapping:

**TreeHaver::Parser (top level) handles ALL wrapping and unwrapping.**
**Backends work exclusively with raw backend objects.**
**User-facing API uses only TreeHaver wrapper classes.**

This ensures:
- ✅ Consistency across all backends
- ✅ Predictable behavior (PoLS)
- ✅ Single place for complexity
- ✅ Simple backend implementations
- ✅ Easy debugging

## Architecture Overview

```
User Code → TreeHaver::Parser → Backend → Raw Objects
            ↑ wraps/unwraps ↑    ↓ raw in/out ↓
User Code ← TreeHaver::Tree ←────┘
            TreeHaver::Node
```

## Language Objects

### Wrapping Contract

**Input to `TreeHaver::Parser#language=`:**
- User passes: `TreeHaver::Backends::*::Language` wrapper OR raw language object

**TreeHaver::Parser unwraps:**
- Calls `unwrap_language(lang)` helper method
- Passes unwrapped object to `backend.language=`

**Backend receives:**
- MRI: `::TreeSitter::Language` (raw)
- Rust: `String` (language name)
- FFI: `TreeHaver::Backends::FFI::Language` (wrapper - needs `to_ptr`)
- Java: Java Language object (unwrapped from wrapper's `impl`)
- Citrus: `Module` (grammar module)

### Unwrapping Logic

Located in `TreeHaver::Parser#unwrap_language`:

```ruby
def unwrap_language(lang)
  # Check specific wrapper types using class.name string comparison
  # This approach is consistent, safe, and avoids autoload timing issues

  # Rust wrapper - extract language name string
  if lang.class.name == "TreeHaver::Backends::Rust::Language"
    return lang.name
  end

  # FFI wrapper - return as-is (needs to_ptr)
  if lang.class.name == "TreeHaver::Backends::FFI::Language"
    return lang
  end

  # MRI wrapper - has specific unwrapping methods (checked via respond_to?)
  return lang.to_language if lang.respond_to?(:to_language)
  return lang.inner_language if lang.respond_to?(:inner_language)

  # Java wrapper - extract impl
  if lang.class.name == "TreeHaver::Backends::Java::Language"
    return lang.impl
  end

  # Citrus wrapper - extract grammar module
  if lang.class.name == "TreeHaver::Backends::Citrus::Language"
    return lang.grammar_module
  end

  # Fallback for generic checks (backwards compatibility)
  return lang.impl if lang.respond_to?(:impl)
  return lang.grammar_module if lang.respond_to?(:grammar_module)

  lang  # Raw language, pass through
end
```

**Special Case: FFI Backend**
- FFI is unique: it needs the wrapped `Language` object to call `to_ptr`
- **CRITICAL:** Must check `lang.is_a?(Backends::FFI::Language)` specifically
- **NOT** just `respond_to?(:to_ptr)` - raw backend objects might also respond to this
- If we pass a non-FFI object that responds to `:to_ptr`, we get a segfault!
- FFI backend's `language=` expects the wrapper, not unwrapped pointer

**Why Class Name String Checks Are Critical:**

We use `lang.class.name == "TreeHaver::Backends::*::Language"` instead of `lang.is_a?(Backends::*::Language)` for several critical reasons:

1. **Autoload Safety:**
   - Using `is_a?` can trigger autoload at the wrong time
   - String comparison works even if the class isn't fully loaded yet
   - Avoids race conditions during backend initialization

2. **Cross-Backend Safety:**
   - When switching backends, cached objects might be from different backends
   - String comparison reliably distinguishes `FFI::Language` from `MRI::Language`
   - Prevents segfaults when wrong wrapper type is passed to native code

3. **Method Collision Prevention:**
   - **Rust:** Many objects have a `name` method
   - **FFI:** Raw backend objects might respond to `:to_ptr` (causing segfaults!)
   - **Java:** Multiple objects might have an `impl` accessor
   - **Citrus:** Various objects might have `grammar_module`
   - String checks ensure we only match the exact wrapper class

4. **Consistency:**
   - All backend wrappers use the same detection pattern
   - Easier to maintain and reason about
   - Reduces cognitive load when debugging

**MRI Exception:** MRI still uses `respond_to?` checks because `to_language` and `inner_language` are highly specific methods unlikely to collide with other objects.

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
  # Fallback for compatibility with legacy wrappers
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
- [ ] `language=` accepts raw unwrapped object (not TreeHaver wrapper)
- [ ] `language=` returns the object it received (for consistency)
- [ ] No unwrapping logic in backend (TreeHaver::Parser does it)

### Tree Handling (parse)
- [ ] `parse(source)` returns raw backend tree
- [ ] No wrapping in `parse` (TreeHaver::Parser wraps result)

### Tree Handling (parse_string)
- [ ] `parse_string(old_tree, source)` expects raw tree (already unwrapped)
- [ ] `parse_string` returns raw backend tree
- [ ] No unwrapping in `parse_string` (TreeHaver::Parser does it)
- [ ] No wrapping in `parse_string` (TreeHaver::Parser wraps result)

### Documentation
- [ ] Document that backend receives unwrapped objects
- [ ] Document that backend returns unwrapped objects
- [ ] Note that TreeHaver::Parser handles all wrapping/unwrapping

## Current Backend Status

| Backend | Language | parse | parse_string | Compliant |
|---------|----------|-------|--------------|-----------|
| MRI     | ✅       | ✅    | ✅           | ✅        |
| Rust    | ✅       | ✅    | ✅           | ✅        |
| FFI     | ✅*      | ✅    | N/A          | ✅        |
| Java    | ✅       | ✅    | ✅           | ✅        |
| Citrus  | ✅       | ✅    | ✅           | ✅        |

\* FFI is special case - receives wrapper (needs `to_ptr`)

## Benefits of This Architecture

1. **Single Responsibility:** Only TreeHaver::Parser knows about wrapping
2. **Consistency:** All backends follow the same pattern
3. **Simplicity:** Backends don't need to handle wrapper types
4. **Testability:** Easy to mock at boundaries
5. **Maintainability:** Changes to wrapping logic are centralized
6. **PoLS:** Users never see backend-specific wrapper types
7. **Performance:** No double wrapping/unwrapping

## Anti-Patterns to Avoid

❌ **Don't unwrap in backends:**
```ruby
# BAD - backend doing unwrapping
def language=(lang)
  inner = lang.respond_to?(:inner_language) ? lang.inner_language : lang
  @parser.language = inner
end
```

✅ **Let TreeHaver::Parser unwrap:**
```ruby
# GOOD - backend expects unwrapped
def language=(lang)
  # lang is already unwrapped by TreeHaver::Parser
  @parser.language = lang
  lang
end
```

❌ **Don't wrap in backends:**
```ruby
# BAD - backend doing wrapping
def parse(source)
  raw_tree = @parser.parse(source)
  TreeHaver::Tree.new(raw_tree, source: source)  # Wrong!
end
```

✅ **Return raw objects:**
```ruby
# GOOD - return raw, TreeHaver::Parser wraps
def parse(source)
  @parser.parse(source)  # Return raw tree
end
```

## Migration Guide

If you have existing code that does wrapping/unwrapping in backends:

1. **Remove unwrapping from backend `language=`**
   - TreeHaver::Parser now calls `unwrap_language` first
   - Backend receives raw object

2. **Remove unwrapping from backend `parse_string`**
   - TreeHaver::Parser now unwraps `old_tree.inner_tree`
   - Backend receives raw tree

3. **Remove wrapping from backend `parse` and `parse_string`**
   - Return raw backend objects
   - TreeHaver::Parser wraps them

4. **Update documentation**
   - Note that backend receives unwrapped objects
   - Note that backend returns unwrapped objects

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

