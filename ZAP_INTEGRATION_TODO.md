# Zap Integration TODO

## Status: Nearly Ready ✅
Zap is already structured as a library! Build system exports `zap` module via `src/root.zig`.

---

## Phase 1: Enhanced Library API (Priority: HIGH)

### 1.1 Add High-Level Convenience API
**File:** `src/root.zig`

```zig
// Add these to root.zig exports
pub const ZapContext = struct {
    allocator: std.mem.Allocator,
    config: ?*flare.Config,
    ollama_client: ?*ollama.OllamaClient,
    memory: ?*commit_memory.CommitMemory,

    pub fn init(allocator: std.mem.Allocator) !ZapContext;
    pub fn deinit(self: *ZapContext) void;
    pub fn generateCommit(self: *ZapContext, diff: []const u8) ![]const u8;
    pub fn explainChanges(self: *ZapContext, commit_range: []const u8) ![]const u8;
    pub fn suggestMergeResolution(self: *ZapContext, conflict: []const u8) ![]const u8;
};
```

**Why:** Grim needs a simple, stateful API without CLI overhead.

---

### 1.2 Add C API for Ghostlang FFI
**New File:** `src/c_api.zig`

```zig
//! C API for FFI bindings (ghostlang, other languages)

const std = @import("std");
const zap = @import("root.zig");

export fn zap_context_create() ?*anyopaque;
export fn zap_context_destroy(ctx: ?*anyopaque) void;
export fn zap_generate_commit(ctx: ?*anyopaque, diff: [*c]const u8, diff_len: usize) [*c]u8;
export fn zap_explain_changes(ctx: ?*anyopaque, range: [*c]const u8, range_len: usize) [*c]u8;
export fn zap_free_string(str: [*c]u8) void;
```

**Why:** Ghostlang needs C-compatible exports for FFI calls.

---

### 1.3 Update build.zig for Shared Library
**File:** `build.zig`

Add after line 45:
```zig
// Add shared library build option
const lib = b.addSharedLibrary(.{
    .name = "zap",
    .root_module = mod,
    .target = target,
    .optimize = optimize,
});
b.installArtifact(lib);

// Add C API module
const c_api_mod = b.addModule("zap-c", .{
    .root_source_file = b.path("src/c_api.zig"),
    .target = target,
    .imports = &.{
        .{ .name = "zap", .module = mod },
    },
});
```

**Why:** Grim can dynamically link libzap.so for runtime loading.

---

## Phase 2: Documentation (Priority: MEDIUM)

### 2.1 Add Integration Examples
**New File:** `docs/LIBRARY_USAGE.md`

Topics:
- Importing zap in Zig projects
- Using from Ghostlang (.gza plugins)
- Configuration via flare
- Error handling patterns

### 2.2 Add API Documentation
**New File:** `docs/API.md`

Document:
- All public functions in ollama.zig
- All public functions in commit_memory.zig
- All public functions in ai_detect.zig
- The new ZapContext API

---

## Phase 3: Testing for Library Use (Priority: MEDIUM)

### 3.1 Add Integration Tests
**New File:** `test/integration_test.zig`

Tests:
- Using zap as imported module (not CLI)
- C API calls from Zig
- Error handling without stdout pollution
- Concurrent zap context usage

### 3.2 Add Ghostlang Example
**New File:** `examples/ghostlang_plugin.gza`

Simple .gza plugin demonstrating:
- Loading libzap via FFI
- Calling zap_generate_commit()
- Displaying results in Grim buffer

---

## Phase 4: Git Integration Helpers (Priority: LOW)

### 4.1 Add Git Diff Helper
**New File:** `src/git_helpers.zig`

```zig
pub fn getStagedDiff(allocator: std.mem.Allocator) ![]const u8;
pub fn getUnstagedDiff(allocator: std.mem.Allocator) ![]const u8;
pub fn getCommitRange(allocator: std.mem.Allocator, range: []const u8) ![]const u8;
pub fn getCurrentBranch(allocator: std.mem.Allocator) ![]const u8;
```

**Why:** Grim already has git support, but these helpers reduce duplication.

---

## Optional Enhancements

### Better Async Support
- Wrap Ollama calls with zsync async primitives
- Allow non-blocking commit generation in Grim

### MCP Integration
- Expose zap operations as MCP tools via rune
- Enable Claude Desktop → Grim communication

### Caching Layer
- Cache generated commit messages for identical diffs
- Use zQLite for persistent cache

---

## Dependencies Check ✅
Already satisfied:
- ✅ flash (CLI framework, won't conflict)
- ✅ flare (config, Grim can reuse)
- ✅ zsync (async, useful for Grim)
- ✅ phantom (TUI, compatible)
- ✅ rune (MCP, bonus feature)

---

## Timeline Estimate
- **Phase 1:** 4-6 hours (core API additions)
- **Phase 2:** 2-3 hours (documentation)
- **Phase 3:** 3-4 hours (tests + examples)
- **Phase 4:** 2-3 hours (git helpers)

**Total:** ~12-16 hours for full integration readiness
