//! CLI Command System for Zap
//! Handles parsing and executing zap commands

const std = @import("std");
const ai_detect = @import("ai_detect.zig");
const commit_memory = @import("commit_memory.zig");

/// Main CLI entry point
pub fn runCli(allocator: std.mem.Allocator) !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "commit")) {
        try handleCommit(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "detect-ai")) {
        try handleDetectAI(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "help")) {
        try printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try printUsage();
        return error.UnknownCommand;
    }
}

/// Handle the commit command with AI assistance
pub fn handleCommit(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args; // TODO: Parse commit flags

    // Initialize commit memory
    var memory = commit_memory.CommitMemory.init(allocator);
    defer memory.deinit();

    // Load existing patterns
    const zap_dir = try getZapDir(allocator);
    defer allocator.free(zap_dir);
    memory.loadFromDisk(zap_dir) catch |err| {
        std.debug.print("Warning: Could not load commit patterns: {}\n", .{err});
    };

    // Get current git status
    const staged_files = try getStagedFiles(allocator);
    defer {
        for (staged_files) |file| allocator.free(file);
        allocator.free(staged_files);
    }

    // Detect AI usage in recent commits
    const ai_detection = try detectRecentAIUsage(allocator);
    if (ai_detection.assistant != .unknown) {
        std.debug.print("🤖 Detected {s} usage (confidence: {d:.2})\n", .{
            @tagName(ai_detection.assistant),
            ai_detection.confidence,
        });

        // Suggest staging pattern
        if (try memory.suggestStagingPattern(ai_detection.assistant, staged_files)) |suggestion| {
            defer allocator.free(suggestion);
            std.debug.print("💡 {s}\n", .{suggestion});
        }
    }

    // For now, just show what we detected
    std.debug.print("Staged files:\n", .{});
    for (staged_files) |file| {
        std.debug.print("  {s}\n", .{file});
    }

    // TODO: Generate commit message, etc.
    std.debug.print("\n🚀 Ready to commit! (AI-enhanced workflow coming soon)\n", .{});
}

/// Handle AI detection command
pub fn handleDetectAI(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: zap detect-ai <commit-message>\n", .{});
        return;
    }

    const message = args[0];
    const detection = ai_detect.detectFromCommitMessage(message);

    std.debug.print("AI Detection Result:\n", .{});
    std.debug.print("  Assistant: {s}\n", .{@tagName(detection.assistant)});
    std.debug.print("  Confidence: {d:.2}\n", .{detection.confidence});
    std.debug.print("  Evidence: {s}\n", .{detection.evidence});
}

/// Get the .zap directory path
pub fn getZapDir(allocator: std.mem.Allocator) ![]const u8 {
    const cwd = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(cwd);

    const dir = std.fs.path.dirname(cwd) orelse ".";
    return try std.fs.path.join(allocator, &[_][]const u8{ dir, ".zap" });
}

/// Get list of staged files from git
pub fn getStagedFiles(allocator: std.mem.Allocator) ![][]const u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "diff", "--cached", "--name-only" },
    });
    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        return error.GitCommandFailed;
    }

    var files = std.ArrayListUnmanaged([]const u8){};
    defer files.deinit(allocator);
    var lines = std.mem.split(u8, result.stdout, "\n");
    while (lines.next()) |line| {
        if (line.len > 0) {
            try files.append(allocator, try allocator.dupe(u8, line));
        }
    }

    return files.toOwnedSlice(allocator);
}

/// Detect AI usage in recent commits
pub fn detectRecentAIUsage(allocator: std.mem.Allocator) !ai_detect.AIDetection {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "log", "--oneline", "-5" },
    });
    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        return ai_detect.AIDetection{
            .assistant = .unknown,
            .confidence = 0.0,
            .evidence = "could not read git log",
        };
    }

    // Check recent commit messages for AI patterns
    var highest_confidence: f32 = 0.0;
    var best_detection = ai_detect.AIDetection{
        .assistant = .unknown,
        .confidence = 0.0,
        .evidence = "no AI patterns in recent commits",
    };

    var lines = std.mem.split(u8, result.stdout, "\n");
    while (lines.next()) |line| {
        // Skip the commit hash, get the message
        if (std.mem.indexOf(u8, line, " ")) |space_pos| {
            const message = line[space_pos + 1 ..];
            const detection = ai_detect.detectFromCommitMessage(message);
            if (detection.confidence > highest_confidence) {
                highest_confidence = detection.confidence;
                best_detection = detection;
            }
        }
    }

    return best_detection;
}

/// Print usage information
pub fn printUsage() !void {
    const usage =
        \\Zap - AI-Powered Git Workflow
        \\
        \\Usage: zap <command> [options]
        \\
        \\Commands:
        \\  commit          Create AI-enhanced commits
        \\  detect-ai       Detect AI assistant usage
        \\  help            Show this help message
        \\
        \\Examples:
        \\  zap commit -a
        \\  zap detect-ai "feat: add new feature with Claude"
        \\
    ;
    std.debug.print("{s}", .{usage});
}
