//! AI Assistant Detection Module
//! Detects changes made by Claude Code and Zeke AI assistants

const std = @import("std");

/// Types of AI assistants we can detect
pub const AIAssistant = enum {
    claude_code,
    zeke,
    unknown,
};

/// Detection result for AI-generated changes
pub const AIDetection = struct {
    assistant: AIAssistant,
    confidence: f32, // 0.0 to 1.0
    evidence: []const u8, // What led to this detection
};

/// Detect AI assistant from commit message
pub fn detectFromCommitMessage(message: []const u8) AIDetection {
    // Check for Claude Code patterns
    if (std.mem.indexOf(u8, message, "Claude") != null or
        std.mem.indexOf(u8, message, "claude-code") != null or
        std.mem.indexOf(u8, message, "anthropic") != null)
    {
        return AIDetection{
            .assistant = .claude_code,
            .confidence = 0.8,
            .evidence = "commit message contains Claude references",
        };
    }

    // Check for Zeke patterns
    if (std.mem.indexOf(u8, message, "Zeke") != null or
        std.mem.indexOf(u8, message, "zeke") != null or
        std.mem.indexOf(u8, message, "zeke.nvim") != null or
        std.mem.indexOf(u8, message, "zeke.gza") != null)
    {
        return AIDetection{
            .assistant = .zeke,
            .confidence = 0.9,
            .evidence = "commit message contains Zeke references",
        };
    }

    return AIDetection{
        .assistant = .unknown,
        .confidence = 0.0,
        .evidence = "no AI assistant patterns detected",
    };
}

/// Detect AI assistant from file changes (future enhancement)
pub fn detectFromFileChanges(allocator: std.mem.Allocator, changed_files: []const []const u8) !AIDetection {
    _ = allocator;
    _ = changed_files;
    // TODO: Implement file pattern analysis
    // Could look for patterns like:
    // - Files typically modified by AI assistants
    // - Code style patterns
    // - Comment patterns

    return AIDetection{
        .assistant = .unknown,
        .confidence = 0.0,
        .evidence = "file change analysis not implemented",
    };
}

/// Detect AI assistant from git author/committer info
pub fn detectFromGitInfo(author: []const u8, committer: []const u8) AIDetection {
    // Check for known AI assistant email patterns
    const ai_patterns = [_][]const u8{
        "claude-code",
        "anthropic",
        "zeke",
        "ai-assistant",
    };

    for (ai_patterns) |pattern| {
        if (std.mem.indexOf(u8, author, pattern) != null or
            std.mem.indexOf(u8, committer, pattern) != null)
        {
            if (std.mem.indexOf(u8, author, "claude") != null or
                std.mem.indexOf(u8, committer, "claude") != null)
            {
                return AIDetection{
                    .assistant = .claude_code,
                    .confidence = 0.7,
                    .evidence = "git author/committer contains Claude patterns",
                };
            }
            if (std.mem.indexOf(u8, author, "zeke") != null or
                std.mem.indexOf(u8, committer, "zeke") != null)
            {
                return AIDetection{
                    .assistant = .zeke,
                    .confidence = 0.8,
                    .evidence = "git author/committer contains Zeke patterns",
                };
            }
        }
    }

    return AIDetection{
        .assistant = .unknown,
        .confidence = 0.0,
        .evidence = "no AI patterns in git info",
    };
}

/// Combined detection using multiple sources
pub fn detectAIUsage(allocator: std.mem.Allocator, commit_message: []const u8, author: []const u8, committer: []const u8, changed_files: ?[]const []const u8) !AIDetection {
    // Start with commit message detection
    var detection = detectFromCommitMessage(commit_message);

    // If confidence is low, check git info
    if (detection.confidence < 0.5) {
        const git_detection = detectFromGitInfo(author, committer);
        if (git_detection.confidence > detection.confidence) {
            detection = git_detection;
        }
    }

    // Future: Check file changes if provided
    if (changed_files) |files| {
        const file_detection = try detectFromFileChanges(allocator, files);
        if (file_detection.confidence > detection.confidence) {
            detection = file_detection;
        }
    }

    return detection;
}

/// Detect AI usage in recent commits
pub fn detectRecentAIUsage(allocator: std.mem.Allocator) !AIDetection {
    _ = allocator;
    // For now, return unknown to avoid memory issues
    // TODO: Implement proper git log parsing
    return AIDetection{
        .assistant = .unknown,
        .confidence = 0.0,
        .evidence = "AI detection temporarily disabled",
    };
}

test "detect Claude Code from commit message" {
    const message = "feat: add new feature implemented by Claude";
    const detection = detectFromCommitMessage(message);
    try std.testing.expectEqual(AIAssistant.claude_code, detection.assistant);
    try std.testing.expect(detection.confidence > 0.5);
}

test "detect Zeke from commit message" {
    const message = "fix: bug resolved using zeke";
    const detection = detectFromCommitMessage(message);
    try std.testing.expectEqual(AIAssistant.zeke, detection.assistant);
    try std.testing.expect(detection.confidence > 0.5);
}

test "no detection for regular commits" {
    const message = "feat: add user authentication";
    const detection = detectFromCommitMessage(message);
    try std.testing.expectEqual(AIAssistant.unknown, detection.assistant);
    try std.testing.expectEqual(@as(f32, 0.0), detection.confidence);
}
