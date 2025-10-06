//! C API for FFI bindings (ghostlang, other languages)
//! Provides C-compatible exports for zap functionality

const std = @import("std");
const zap = @import("root.zig");

/// Opaque handle to ZapContext
pub const ZapContextHandle = *anyopaque;

var global_allocator: ?std.mem.Allocator = null;

/// Initialize global allocator (call once before any other functions)
export fn zap_init_allocator() void {
    if (global_allocator == null) {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        global_allocator = gpa.allocator();
    }
}

/// Create a new zap context
export fn zap_context_create() ?ZapContextHandle {
    const allocator = global_allocator orelse return null;

    const ctx = allocator.create(zap.ZapContext) catch return null;
    ctx.* = zap.ZapContext.init(allocator) catch {
        allocator.destroy(ctx);
        return null;
    };

    return @ptrCast(ctx);
}

/// Create zap context with custom ollama config
export fn zap_context_create_with_config(
    host: [*:0]const u8,
    model: [*:0]const u8,
    timeout_ms: u32,
) ?ZapContextHandle {
    const allocator = global_allocator orelse return null;

    const host_slice = std.mem.span(host);
    const model_slice = std.mem.span(model);

    const config = zap.ollama.OllamaConfig{
        .host = host_slice,
        .model = model_slice,
        .timeout_ms = timeout_ms,
    };

    const ctx = allocator.create(zap.ZapContext) catch return null;
    ctx.* = zap.ZapContext.initWithConfig(allocator, config) catch {
        allocator.destroy(ctx);
        return null;
    };

    return @ptrCast(ctx);
}

/// Destroy zap context
export fn zap_context_destroy(handle: ?ZapContextHandle) void {
    const ctx: *zap.ZapContext = @ptrCast(@alignCast(handle orelse return));
    const allocator = ctx.allocator;
    ctx.deinit();
    allocator.destroy(ctx);
}

/// Generate commit message from git diff
/// Returns null-terminated string (must be freed with zap_free_string)
export fn zap_generate_commit(handle: ?ZapContextHandle, diff: [*:0]const u8) ?[*:0]u8 {
    const ctx: *zap.ZapContext = @ptrCast(@alignCast(handle orelse return null));
    const diff_slice = std.mem.span(diff);

    const message = ctx.generateCommit(diff_slice) catch return null;

    // Add null terminator
    const result = ctx.allocator.allocSentinel(u8, message.len, 0) catch {
        ctx.allocator.free(message);
        return null;
    };
    @memcpy(result, message);
    ctx.allocator.free(message);

    return result.ptr;
}

/// Explain code changes from commit range
/// Returns null-terminated string (must be freed with zap_free_string)
export fn zap_explain_changes(handle: ?ZapContextHandle, commit_range: [*:0]const u8) ?[*:0]u8 {
    const ctx: *zap.ZapContext = @ptrCast(@alignCast(handle orelse return null));
    const range_slice = std.mem.span(commit_range);

    const explanation = ctx.explainChanges(range_slice) catch return null;

    // Add null terminator
    const result = ctx.allocator.allocSentinel(u8, explanation.len, 0) catch {
        ctx.allocator.free(explanation);
        return null;
    };
    @memcpy(result, explanation);
    ctx.allocator.free(explanation);

    return result.ptr;
}

/// Suggest merge conflict resolution
/// Returns null-terminated string (must be freed with zap_free_string)
export fn zap_suggest_merge_resolution(handle: ?ZapContextHandle, conflict: [*:0]const u8) ?[*:0]u8 {
    const ctx: *zap.ZapContext = @ptrCast(@alignCast(handle orelse return null));
    const conflict_slice = std.mem.span(conflict);

    const suggestion = ctx.suggestMergeResolution(conflict_slice) catch return null;

    // Add null terminator
    const result = ctx.allocator.allocSentinel(u8, suggestion.len, 0) catch {
        ctx.allocator.free(suggestion);
        return null;
    };
    @memcpy(result, suggestion);
    ctx.allocator.free(suggestion);

    return result.ptr;
}

/// Check if Ollama is available
export fn zap_is_available(handle: ?ZapContextHandle) bool {
    const ctx: *zap.ZapContext = @ptrCast(@alignCast(handle orelse return false));
    return ctx.isAvailable() catch false;
}

/// Free a string returned by zap functions
export fn zap_free_string(handle: ?ZapContextHandle, str: ?[*:0]u8) void {
    const ctx: *zap.ZapContext = @ptrCast(@alignCast(handle orelse return));
    const ptr: [*:0]u8 = str orelse return;
    const slice = std.mem.span(ptr);
    ctx.allocator.free(slice);
}

/// Get last error message (returns static string, do not free)
export fn zap_get_last_error() [*:0]const u8 {
    return "Not implemented yet";
}
