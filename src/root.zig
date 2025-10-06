//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

// Export our modules
pub const ai_detect = @import("ai_detect.zig");
pub const commit_memory = @import("commit_memory.zig");
pub const ollama = @import("ollama.zig");

/// High-level context for zap operations
/// Provides a simple stateful API for library consumers (Grim, etc.)
pub const ZapContext = struct {
    allocator: std.mem.Allocator,
    ollama_client: ?*ollama.OllamaClient,
    memory: ?*commit_memory.CommitMemory,
    config: ollama.OllamaConfig,
    initialized: bool = false,

    /// Initialize zap context with default configuration
    pub fn init(allocator: std.mem.Allocator) !ZapContext {
        return ZapContext{
            .allocator = allocator,
            .ollama_client = null,
            .memory = null,
            .config = .{
                .host = "http://localhost:11434",
                .model = "deepseek-coder:33b",
                .timeout_ms = 30000,
            },
            .initialized = false,
        };
    }

    /// Initialize with custom ollama config
    pub fn initWithConfig(allocator: std.mem.Allocator, config: ollama.OllamaConfig) !ZapContext {
        var ctx = try init(allocator);
        ctx.config = config;
        return ctx;
    }

    /// Lazy init ollama client
    fn ensureOllama(self: *ZapContext) !void {
        if (self.ollama_client != null) return;

        const client = try self.allocator.create(ollama.OllamaClient);
        errdefer self.allocator.destroy(client);
        client.* = try ollama.OllamaClient.init(self.allocator, self.config);
        self.ollama_client = client;
    }

    /// Lazy init commit memory
    fn ensureMemory(self: *ZapContext) !void {
        if (self.memory != null) return;

        const mem = try self.allocator.create(commit_memory.CommitMemory);
        mem.* = commit_memory.CommitMemory.init(self.allocator);
        self.memory = mem;
    }

    pub fn deinit(self: *ZapContext) void {
        if (self.ollama_client) |client| {
            self.allocator.destroy(client);
        }
        if (self.memory) |mem| {
            mem.deinit();
            self.allocator.destroy(mem);
        }
        self.initialized = false;
    }

    /// Generate commit message from git diff
    pub fn generateCommit(self: *ZapContext, diff: []const u8) ![]const u8 {
        try self.ensureOllama();
        return try self.ollama_client.?.generateCommitMessage(diff);
    }

    /// Explain code changes in plain English
    pub fn explainChanges(self: *ZapContext, commit_range: []const u8) ![]const u8 {
        try self.ensureOllama();

        const prompt = try std.fmt.allocPrint(self.allocator,
            \\Explain what changed in commit range {s}.
            \\Summarize the overall changes, their purpose, and impact.
            \\Be concise and focus on the "why" behind changes.
        , .{commit_range});
        defer self.allocator.free(prompt);

        const request = ollama.GenerateRequest{
            .model = self.config.model,
            .prompt = prompt,
            .stream = false,
            .options = .{
                .temperature = 0.5,
                .num_predict = 400,
            },
        };

        return try self.ollama_client.?.generate(request);
    }

    /// Suggest merge conflict resolution
    pub fn suggestMergeResolution(self: *ZapContext, conflict: []const u8) ![]const u8 {
        try self.ensureOllama();

        const prompt = try std.fmt.allocPrint(self.allocator,
            \\This is a git merge conflict:
            \\
            \\{s}
            \\
            \\Suggest how to resolve it. Consider both sides and propose a solution.
            \\Explain the reasoning behind your suggestion.
        , .{conflict});
        defer self.allocator.free(prompt);

        const request = ollama.GenerateRequest{
            .model = self.config.model,
            .prompt = prompt,
            .stream = false,
            .system = "You are a git expert helping resolve merge conflicts.",
            .options = .{
                .temperature = 0.4,
                .num_predict = 400,
            },
        };

        return try self.ollama_client.?.generate(request);
    }

    /// Check if Ollama is available
    pub fn isAvailable(self: *ZapContext) !bool {
        try self.ensureOllama();
        return try self.ollama_client.?.ping();
    }

    /// Remember a commit pattern for future use
    pub fn rememberCommit(self: *ZapContext, pattern: commit_memory.CommitPattern) !void {
        try self.ensureMemory();
        try self.memory.?.rememberPattern(pattern);
    }
};

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
