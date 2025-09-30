//! Ollama AI Integration Module
//! Provides local LLM capabilities for commit message generation and AI assistance

const std = @import("std");

/// Ollama client configuration
pub const OllamaConfig = struct {
    host: []const u8 = "http://localhost:11434",
    model: []const u8 = "deepseek-coder:33b", // Good coding model
    timeout_ms: u32 = 30000, // 30 seconds
};

/// Ollama API response for generation
pub const GenerateResponse = struct {
    model: []const u8,
    created_at: []const u8,
    response: []const u8,
    done: bool,
    context: ?[]const i64 = null,
    total_duration: ?u64 = null,
    load_duration: ?u64 = null,
    prompt_eval_count: ?u32 = null,
    prompt_eval_duration: ?u64 = null,
    eval_count: ?u32 = null,
    eval_duration: ?u64 = null,
};

/// Ollama API request for generation
pub const GenerateRequest = struct {
    model: []const u8,
    prompt: []const u8,
    stream: bool = false,
    context: ?[]const i64 = null,
    system: ?[]const u8 = null,
    template: ?[]const u8 = null,
    format: ?[]const u8 = null,
    raw: ?bool = null,
    options: ?GenerateOptions = null,
};

/// Generation options
pub const GenerateOptions = struct {
    num_predict: ?i32 = null,
    temperature: ?f32 = null,
    top_k: ?i32 = null,
    top_p: ?f32 = null,
    repeat_penalty: ?f32 = null,
    presence_penalty: ?f32 = null,
    frequency_penalty: ?f32 = null,
};

/// Ollama client for AI operations
pub const OllamaClient = struct {
    allocator: std.mem.Allocator,
    config: OllamaConfig,

    const Self = @This();

    /// Initialize Ollama client
    pub fn init(allocator: std.mem.Allocator, config: OllamaConfig) !Self {
        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Generate a commit message from git diff
    pub fn generateCommitMessage(self: *Self, diff: []const u8) ![]const u8 {
        // Analyze the diff to create a concise summary
        const summary = try self.summarizeDiff(diff);
        defer self.allocator.free(summary);

        const prompt = try std.fmt.allocPrint(self.allocator,
            \\Write a concise git commit message for these changes: {s}
            \\Follow conventional commit format. Keep under 72 characters.
        , .{summary});
        defer self.allocator.free(prompt);

        const request = GenerateRequest{
            .model = self.config.model,
            .prompt = prompt,
            .stream = false,
            .options = .{
                .temperature = 0.3, // Lower temperature for more focused responses
                .num_predict = 100, // Limit response length
            },
        };

        return try self.generate(request);
    }

    /// Summarize a git diff into key changes
    pub fn summarizeDiff(self: *Self, diff: []const u8) ![]const u8 {
        var files_added = std.ArrayListUnmanaged([]const u8){};
        defer files_added.deinit(self.allocator);
        var files_modified = std.ArrayListUnmanaged([]const u8){};
        defer files_modified.deinit(self.allocator);
        var files_deleted = std.ArrayListUnmanaged([]const u8){};
        defer files_deleted.deinit(self.allocator);

        var lines = std.mem.splitScalar(u8, diff, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "diff --git")) {
                // Extract filename from diff --git a/file b/file
                var parts = std.mem.splitScalar(u8, line, ' ');
                _ = parts.next(); // skip "diff"
                _ = parts.next(); // skip "--git"
                const a_file = parts.next() orelse continue;
                const b_file = parts.next() orelse continue;

                // Remove "a/" or "b/" prefix
                const filename = if (std.mem.startsWith(u8, b_file, "b/"))
                    b_file[2..]
                else if (std.mem.startsWith(u8, a_file, "a/"))
                    a_file[2..]
                else
                    b_file;

                // Check next few lines to determine change type
                var found_new_file = false;
                var found_deleted_file = false;
                var line_count: usize = 0;

                // Look at next few lines
                while (lines.next()) |next_line| {
                    line_count += 1;
                    if (line_count > 5) break; // Don't look too far

                    if (std.mem.startsWith(u8, next_line, "new file mode")) {
                        found_new_file = true;
                        break;
                    }
                    if (std.mem.startsWith(u8, next_line, "deleted file mode")) {
                        found_deleted_file = true;
                        break;
                    }
                    // Stop if we hit another diff
                    if (std.mem.startsWith(u8, next_line, "diff --git")) {
                        break;
                    }
                }

                const filename_copy = try self.allocator.dupe(u8, filename);
                if (found_new_file) {
                    try files_added.append(self.allocator, filename_copy);
                } else if (found_deleted_file) {
                    try files_deleted.append(self.allocator, filename_copy);
                } else {
                    try files_modified.append(self.allocator, filename_copy);
                }
            }
        }

        // Build summary
        var summary = std.ArrayListUnmanaged(u8){};
        defer summary.deinit(self.allocator);

        if (files_added.items.len > 0) {
            try summary.appendSlice(self.allocator, "Added ");
            for (files_added.items, 0..) |file, i| {
                if (i > 0) try summary.appendSlice(self.allocator, ", ");
                try summary.appendSlice(self.allocator, std.fs.path.extension(file));
                self.allocator.free(file);
            }
            if (files_modified.items.len > 0 or files_deleted.items.len > 0) {
                try summary.appendSlice(self.allocator, "; ");
            }
        }

        if (files_modified.items.len > 0) {
            try summary.appendSlice(self.allocator, "Modified ");
            for (files_modified.items, 0..) |file, i| {
                if (i > 0) try summary.appendSlice(self.allocator, ", ");
                try summary.appendSlice(self.allocator, std.fs.path.extension(file));
                self.allocator.free(file);
            }
            if (files_deleted.items.len > 0) {
                try summary.appendSlice(self.allocator, "; ");
            }
        }

        if (files_deleted.items.len > 0) {
            try summary.appendSlice(self.allocator, "Deleted ");
            for (files_deleted.items, 0..) |file, i| {
                if (i > 0) try summary.appendSlice(self.allocator, ", ");
                try summary.appendSlice(self.allocator, std.fs.path.extension(file));
                self.allocator.free(file);
            }
        }

        if (summary.items.len == 0) {
            return try self.allocator.dupe(u8, "various changes");
        }

        return summary.toOwnedSlice(self.allocator);
    }

    /// Generate text using Ollama API
    pub fn generate(self: *Self, request: GenerateRequest) ![]const u8 {
        const opts = request.options orelse GenerateOptions{};

        var builder = std.ArrayListUnmanaged(u8){};
        defer builder.deinit(self.allocator);
        var first_field = true;

        try builder.append(self.allocator, '{');
        try appendJsonFieldString(self.allocator, &builder, &first_field, "model", request.model);
        try appendJsonFieldString(self.allocator, &builder, &first_field, "prompt", request.prompt);
        try appendJsonFieldBool(self.allocator, &builder, &first_field, "stream", request.stream);

        if (request.context) |ctx| {
            const context_json = try formatIntArray(self.allocator, ctx);
            defer self.allocator.free(context_json);
            try appendJsonFieldRaw(self.allocator, &builder, &first_field, "context", context_json);
        }

        if (request.system) |system| {
            try appendJsonFieldString(self.allocator, &builder, &first_field, "system", system);
        }

        if (request.template) |template| {
            try appendJsonFieldString(self.allocator, &builder, &first_field, "template", template);
        }

        if (request.format) |format| {
            try appendJsonFieldString(self.allocator, &builder, &first_field, "format", format);
        }

        if (request.raw) |raw_flag| {
            try appendJsonFieldBool(self.allocator, &builder, &first_field, "raw", raw_flag);
        }

        const options_json = try buildOptionsJson(self.allocator, opts);
        defer self.allocator.free(options_json);
        try appendJsonFieldRaw(self.allocator, &builder, &first_field, "options", options_json);

        try builder.append(self.allocator, '}');
        const json_payload = try builder.toOwnedSlice(self.allocator);
        defer self.allocator.free(json_payload);

        // Create temporary file for payload
        const temp_file = try std.fmt.allocPrint(self.allocator, "/tmp/zap_ollama_payload_{d}.json", .{std.time.timestamp()});
        defer self.allocator.free(temp_file);

        var tmp_file = try std.fs.createFileAbsolute(temp_file, .{ .truncate = true });
        try tmp_file.writeAll(json_payload);
        tmp_file.close();
        defer std.fs.deleteFileAbsolute(temp_file) catch {};

        // Use curl with temp file
        const curl_cmd = try std.fmt.allocPrint(self.allocator,
            \\curl -s -X POST {s}/api/generate -H "Content-Type: application/json" -d @{s}
        , .{ self.config.host, temp_file });
        defer self.allocator.free(curl_cmd);

        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "sh", "-c", curl_cmd },
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term != .Exited or result.term.Exited != 0) {
            std.debug.print("Ollama request failed with exit code {}: {s}\n", .{result.term.Exited, result.stderr});
            return error.OllamaRequestFailed;
        }

        var doc = try std.json.parseFromSlice(std.json.Value, self.allocator, result.stdout, .{
            .ignore_unknown_fields = true,
        });
        defer doc.deinit();

        if (doc.value != .object) {
            std.debug.print("Unexpected Ollama response: {s}\n", .{result.stdout});
            return error.InvalidOllamaResponse;
        }

        const obj = doc.value.object;

        if (obj.get("error")) |err_val| {
            if (err_val == .string) {
                std.debug.print("Ollama error: {s}\n", .{err_val.string});
            }
            return error.OllamaRequestFailed;
        }

        const response_val = obj.get("response") orelse {
            std.debug.print("Missing response field in Ollama payload: {s}\n", .{result.stdout});
            return error.InvalidOllamaResponse;
        };

        if (response_val != .string) {
            std.debug.print("Unexpected response type from Ollama: {s}\n", .{result.stdout});
            return error.InvalidOllamaResponse;
        }

        return self.allocator.dupe(u8, response_val.string);
    }

    /// Check if Ollama is available and get version info
    pub fn ping(self: *Self) !bool {
        const curl_cmd = try std.fmt.allocPrint(self.allocator,
            \\curl -s --max-time 5 {s}/api/version
        , .{self.config.host});
        defer self.allocator.free(curl_cmd);

        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "sh", "-c", curl_cmd },
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        return result.term == .Exited and result.term.Exited == 0;
    }

    /// List available models
    pub fn listModels(self: *Self) ![]const u8 {
        const curl_cmd = try std.fmt.allocPrint(self.allocator,
            \\curl -s {s}/api/tags
        , .{self.config.host});
        defer self.allocator.free(curl_cmd);

        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "sh", "-c", curl_cmd },
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term != .Exited or result.term.Exited != 0) {
            return error.OllamaRequestFailed;
        }

        return self.allocator.dupe(u8, result.stdout);
    }
};

fn escapeJsonString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out = std.ArrayListUnmanaged(u8){};
    defer out.deinit(allocator);

    try out.append(allocator, '"');
    for (input) |c| switch (c) {
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '"' => try out.appendSlice(allocator, "\\\""),
        '\n' => try out.appendSlice(allocator, "\\n"),
        '\r' => try out.appendSlice(allocator, "\\r"),
        '\t' => try out.appendSlice(allocator, "\\t"),
        else => try out.append(allocator, c),
    };
    try out.append(allocator, '"');

    return out.toOwnedSlice(allocator);
}

fn appendJsonFieldRaw(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, raw: []const u8) !void {
    if (!first.*) try builder.append(allocator, ',');
    first.* = false;

    const escaped_name = try escapeJsonString(allocator, name);
    defer allocator.free(escaped_name);

    try builder.appendSlice(allocator, escaped_name);
    try builder.append(allocator, ':');
    try builder.appendSlice(allocator, raw);
}

fn appendJsonFieldString(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, value: []const u8) !void {
    const escaped = try escapeJsonString(allocator, value);
    defer allocator.free(escaped);
    try appendJsonFieldRaw(allocator, builder, first, name, escaped);
}

fn appendJsonFieldBool(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, value: bool) !void {
    const raw = if (value) "true" else "false";
    try appendJsonFieldRaw(allocator, builder, first, name, raw);
}

fn appendJsonFieldInt(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, value: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, "{d}", .{value});
    defer allocator.free(text);
    try appendJsonFieldRaw(allocator, builder, first, name, text);
}

fn appendJsonFieldFloat(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, value: f64) !void {
    const text = try std.fmt.allocPrint(allocator, "{d}", .{value});
    defer allocator.free(text);
    try appendJsonFieldRaw(allocator, builder, first, name, text);
}

fn formatIntArray(allocator: std.mem.Allocator, values: []const i64) ![]u8 {
    var builder = std.ArrayListUnmanaged(u8){};
    defer builder.deinit(allocator);
    var first = true;

    try builder.append(allocator, '[');
    for (values) |value| {
        if (!first) try builder.append(allocator, ',');
        first = false;
        const text = try std.fmt.allocPrint(allocator, "{d}", .{value});
        try builder.appendSlice(allocator, text);
        allocator.free(text);
    }
    try builder.append(allocator, ']');

    return builder.toOwnedSlice(allocator);
}

fn buildOptionsJson(allocator: std.mem.Allocator, opts: GenerateOptions) ![]u8 {
    var builder = std.ArrayListUnmanaged(u8){};
    defer builder.deinit(allocator);
    var first = true;

    try builder.append(allocator, '{');

    if (opts.num_predict) |num| {
        try appendJsonFieldInt(allocator, &builder, &first, "num_predict", num);
    }
    if (opts.temperature) |temperature| {
        try appendJsonFieldFloat(allocator, &builder, &first, "temperature", @as(f64, @floatCast(temperature)));
    }
    if (opts.top_k) |top_k| {
        try appendJsonFieldInt(allocator, &builder, &first, "top_k", top_k);
    }
    if (opts.top_p) |top_p| {
        try appendJsonFieldFloat(allocator, &builder, &first, "top_p", @as(f64, @floatCast(top_p)));
    }
    if (opts.repeat_penalty) |penalty| {
        try appendJsonFieldFloat(allocator, &builder, &first, "repeat_penalty", @as(f64, @floatCast(penalty)));
    }
    if (opts.presence_penalty) |penalty| {
        try appendJsonFieldFloat(allocator, &builder, &first, "presence_penalty", @as(f64, @floatCast(penalty)));
    }
    if (opts.frequency_penalty) |penalty| {
        try appendJsonFieldFloat(allocator, &builder, &first, "frequency_penalty", @as(f64, @floatCast(penalty)));
    }

    try builder.append(allocator, '}');
    return builder.toOwnedSlice(allocator);
}
