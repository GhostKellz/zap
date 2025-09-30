//! Commit Pattern Memory Module
//! Remembers successful commit staging patterns for workflow improvement

const std = @import("std");
const ai_detect = @import("ai_detect.zig");

/// A remembered commit pattern
pub const CommitPattern = struct {
    ai_assistant: ai_detect.AIAssistant,
    staging_pattern: []const u8, // Description of how files were staged
    commit_message: []const u8, // The commit message used
    success_score: f32, // 0.0 to 1.0 based on how well it worked
    timestamp: i64, // Unix timestamp
    file_types: []const []const u8, // Types of files typically staged together
};

/// Memory storage for commit patterns
pub const CommitMemory = struct {
    allocator: std.mem.Allocator,
    patterns: std.ArrayList(CommitPattern),
    max_patterns: usize = 100, // Limit to prevent unbounded growth

    pub fn init(allocator: std.mem.Allocator) CommitMemory {
        return CommitMemory{
            .allocator = allocator,
            .patterns = std.ArrayList(CommitPattern).init(allocator),
        };
    }

    pub fn deinit(self: *CommitMemory) void {
        for (self.patterns.items) |*pattern| {
            self.allocator.free(pattern.staging_pattern);
            self.allocator.free(pattern.commit_message);
            self.allocator.free(pattern.file_types);
        }
        self.patterns.deinit();
    }

    /// Add a new commit pattern to memory
    pub fn rememberPattern(self: *CommitMemory, pattern: CommitPattern) !void {
        // Deep copy the pattern
        const staging_copy = try self.allocator.dupe(u8, pattern.staging_pattern);
        const message_copy = try self.allocator.dupe(u8, pattern.commit_message);
        const file_types_copy = try self.allocator.dupe([]const u8, pattern.file_types);

        const new_pattern = CommitPattern{
            .ai_assistant = pattern.ai_assistant,
            .staging_pattern = staging_copy,
            .commit_message = message_copy,
            .success_score = pattern.success_score,
            .timestamp = pattern.timestamp,
            .file_types = file_types_copy,
        };

        try self.patterns.append(new_pattern);

        // Keep only the most recent patterns
        if (self.patterns.items.len > self.max_patterns) {
            const oldest = self.patterns.orderedRemove(0);
            self.allocator.free(oldest.staging_pattern);
            self.allocator.free(oldest.commit_message);
            self.allocator.free(oldest.file_types);
        }
    }

    /// Find similar patterns for a given AI assistant and file types
    pub fn findSimilarPatterns(self: *CommitMemory, ai_assistant: ai_detect.AIAssistant, file_types: []const []const u8) ![]CommitPattern {
        var similar = std.ArrayList(CommitPattern).init(self.allocator);
        defer similar.deinit();

        for (self.patterns.items) |pattern| {
            if (pattern.ai_assistant == ai_assistant) {
                // Check if file types overlap
                var overlap_count: usize = 0;
                for (file_types) |ftype| {
                    for (pattern.file_types) |pftype| {
                        if (std.mem.eql(u8, ftype, pftype)) {
                            overlap_count += 1;
                            break;
                        }
                    }
                }

                // If we have some overlap or no specific file types, consider it similar
                if (overlap_count > 0 or file_types.len == 0) {
                    try similar.append(pattern);
                }
            }
        }

        return similar.toOwnedSlice();
    }

    /// Get the best pattern for a given context
    pub fn getBestPattern(self: *CommitMemory, ai_assistant: ai_detect.AIAssistant, file_types: []const []const u8) ?CommitPattern {
        const similar = self.findSimilarPatterns(ai_assistant, file_types) catch return null;
        defer self.allocator.free(similar);

        if (similar.len == 0) return null;

        // Return the pattern with highest success score
        var best = similar[0];
        for (similar[1..]) |pattern| {
            if (pattern.success_score > best.success_score) {
                best = pattern;
            }
        }

        return best;
    }

    /// Suggest staging pattern based on AI assistant and current files
    pub fn suggestStagingPattern(self: *CommitMemory, ai_assistant: ai_detect.AIAssistant, staged_files: []const []const u8) !?[]const u8 {
        // Extract file types from staged files
        var file_types = std.ArrayList([]const u8).init(self.allocator);
        defer file_types.deinit();

        for (staged_files) |file| {
            if (std.fs.path.extension(file).len > 0) {
                const ext = std.fs.path.extension(file);
                try file_types.append(ext);
            } else {
                try file_types.append("no-ext");
            }
        }

        const best_pattern = self.getBestPattern(ai_assistant, file_types.items);
        if (best_pattern) |pattern| {
            return try std.fmt.allocPrint(self.allocator, "Based on previous {s} usage: {s}", .{
                @tagName(ai_assistant),
                pattern.staging_pattern,
            });
        }

        return null;
    }

    /// Load patterns from disk storage
    pub fn loadFromDisk(self: *CommitMemory, zap_dir: []const u8) !void {
        const patterns_file = try std.fs.path.join(self.allocator, &[_][]const u8{ zap_dir, "commit_patterns.json" });
        defer self.allocator.free(patterns_file);

        const file = std.fs.openFileAbsolute(patterns_file, .{}) catch |err| {
            if (err == error.FileNotFound) return; // No existing patterns
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB limit
        defer self.allocator.free(content);

        // TODO: Parse JSON and load patterns
        // For now, this is a placeholder
    }

    /// Save patterns to disk storage
    pub fn saveToDisk(self: *CommitMemory, zap_dir: []const u8) !void {
        const patterns_file = try std.fs.path.join(self.allocator, &[_][]const u8{ zap_dir, "commit_patterns.json" });
        defer self.allocator.free(patterns_file);

        // Ensure .zap directory exists
        std.fs.makeDirAbsolute(zap_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const file = try std.fs.createFileAbsolute(patterns_file, .{});
        defer file.close();

        // TODO: Serialize patterns to JSON
        // For now, write a placeholder
        try file.writeAll("{\"patterns\": []}\n");
    }
};

/// Extract file types from a list of file paths
pub fn extractFileTypes(allocator: std.mem.Allocator, files: []const []const u8) ![]const []const u8 {
    var types = std.ArrayList([]const u8).init(allocator);
    defer types.deinit();

    for (files) |file| {
        const ext = std.fs.path.extension(file);
        if (ext.len > 0) {
            try types.append(ext);
        } else {
            try types.append("no-ext");
        }
    }

    return types.toOwnedSlice();
}

test "commit pattern memory" {
    var memory = CommitMemory.init(std.testing.allocator);
    defer memory.deinit();

    const pattern = CommitPattern{
        .ai_assistant = .zeke,
        .staging_pattern = "staged all .zig files together",
        .commit_message = "feat: add new functionality",
        .success_score = 0.9,
        .timestamp = std.time.timestamp(),
        .file_types = &[_][]const u8{ ".zig", ".md" },
    };

    try memory.rememberPattern(pattern);

    try std.testing.expectEqual(@as(usize, 1), memory.patterns.items.len);
    try std.testing.expectEqual(ai_detect.AIAssistant.zeke, memory.patterns.items[0].ai_assistant);
}

test "find similar patterns" {
    var memory = CommitMemory.init(std.testing.allocator);
    defer memory.deinit();

    // Add a pattern
    const pattern = CommitPattern{
        .ai_assistant = .claude_code,
        .staging_pattern = "staged .zig and .md files",
        .commit_message = "docs: update README",
        .success_score = 0.8,
        .timestamp = std.time.timestamp(),
        .file_types = &[_][]const u8{ ".zig", ".md" },
    };
    try memory.rememberPattern(pattern);

    // Find similar patterns
    const similar = try memory.findSimilarPatterns(.claude_code, &[_][]const u8{".md"});
    defer std.testing.allocator.free(similar);

    try std.testing.expectEqual(@as(usize, 1), similar.len);
}
