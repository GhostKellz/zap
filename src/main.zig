const std = @import("std");
const flash = @import("flash");
const flare = @import("flare");
const zap = @import("zap");

// Configuration structure
const ZapConfig = struct {
    ai_enabled: bool = true,
    remember_patterns: bool = true,
    max_patterns: usize = 100,
    ollama_host: []const u8 = "http://localhost:11434",
    ollama_model: []const u8 = "deepseek-coder:33b",
    ollama_timeout_ms: u32 = 30000,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load configuration
    var config: flare.Config = undefined;
    const config_result = loadConfig(allocator);
    if (config_result) |cfg| {
        config = cfg;
    } else |err| {
        std.debug.print("Warning: Failed to load config: {}\n", .{err});
        // Create a default config
        config = try flare.Config.init(allocator);
    }
    defer config.deinit();

    const ai_enabled = config.getBool("ai_enabled", true) catch true;
    const remember_patterns = config.getBool("remember_patterns", true) catch true;
    const ollama_host = config.getString("ollama.host", "http://localhost:11434") catch "http://localhost:11434";
    const ollama_model = config.getString("ollama.model", "deepseek-coder:33b") catch "deepseek-coder:33b";

    std.debug.print("🤖 Zap v0.1.0 - AI: {s}, Patterns: {s}, Ollama: {s} ({s})\n", .{
        if (ai_enabled) "enabled" else "disabled",
        if (remember_patterns) "enabled" else "disabled",
        ollama_model,
        ollama_host,
    });

    // Create CLI app using Flash
    const CLI = flash.CLI(.{
        .name = "zap",
        .version = "0.1.0",
        .about = "AI-Powered Git Workflow",
    });

    // Define subcommands
    const commit_cmd = flash.Command.init("commit", (flash.CommandConfig{})
        .withAbout("Create AI-enhanced commits")
        .withHandler(handleCommit));

    const explain_cmd = flash.Command.init("explain", (flash.CommandConfig{})
        .withAbout("Explain changes in plain English")
        .withHandler(handleExplain));

    const detect_cmd = flash.Command.init("detect-ai", (flash.CommandConfig{})
        .withAbout("Detect AI assistant usage")
        .withHandler(handleDetectAI));

    const root_config = (flash.CommandConfig{})
        .withSubcommands(&[_]flash.Command{ commit_cmd, explain_cmd, detect_cmd });

    var app = CLI.init(allocator, root_config);

    // Run the CLI
    try app.run();
}

fn loadConfig(allocator: std.mem.Allocator) anyerror!flare.Config {
    // Try to load .zap.toml
    const config_files = [_]flare.FileSource{
        .{
            .path = ".zap.toml",
            .required = false,
            .format = .toml,
        },
    };

    const options = flare.LoadOptions{
        .files = &config_files,
    };

    return try flare.load(allocator, options);
}

fn handleCommit(ctx: flash.Context) (error{ AllocationError, AmbiguousCommand, AsyncExecutionFailed, ConfigError, HelpRequested, IOError, InvalidArgument, InvalidBoolValue, InvalidCharacter, InvalidEnumValue, InvalidFlagValue, InvalidFloatValue, InvalidInput, InvalidIntValue, MissingRequiredArgument, MissingSubcommand, OperationCancelled, OutOfMemory, Overflow, TooFewArguments, TooManyArguments, UnknownCommand, UnknownFlag, ValidationError, VersionRequested })!void {
    _ = ctx;
    std.debug.print("🤖 AI-Enhanced Commit\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load configuration
    var config: flare.Config = undefined;
    const config_result = loadConfig(allocator);
    if (config_result) |cfg| {
        config = cfg;
    } else |err| {
        std.debug.print("Warning: Failed to load config: {}\n", .{err});
        // Create a default config
        config = try flare.Config.init(allocator);
    }
    defer config.deinit();

    const ai_enabled = config.getBool("ai_enabled", true) catch true;
    const ollama_host = config.getString("ollama_host", "http://localhost:11434") catch "http://localhost:11434";
    const ollama_model = config.getString("ollama_model", "deepseek-coder:33b") catch "deepseek-coder:33b";
    const ollama_timeout_ms = config.getInt("ollama_timeout_ms", 30000) catch 30000;

    if (!ai_enabled) {
        std.debug.print("  ❌ AI is disabled in configuration\n", .{});
        return;
    }

    // Initialize Ollama client
    const ollama_config = zap.ollama.OllamaConfig{
        .host = ollama_host,
        .model = ollama_model,
        .timeout_ms = @intCast(ollama_timeout_ms),
    };

    var ollama_client = zap.ollama.OllamaClient.init(allocator, ollama_config) catch |err| {
        std.debug.print("  ❌ Failed to initialize Ollama client: {}\n", .{err});
        return;
    };

    // Check if Ollama is available
    const available = ollama_client.ping() catch false;
    if (!available) {
        std.debug.print("  ❌ Ollama is not available at {s}\n", .{ollama_host});
        std.debug.print("    Make sure Ollama is running: docker start ollama\n", .{});
        return;
    }

    std.debug.print("  📁 Getting git status...\n", .{});

    // Get git diff
    const diff_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "diff", "--cached" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to get git diff: {}\n", .{err});
        return;
    };
    defer allocator.free(diff_result.stdout);
    defer allocator.free(diff_result.stderr);

    if (diff_result.term != .Exited or diff_result.term.Exited != 0) {
        std.debug.print("  ❌ No staged changes found\n", .{});
        std.debug.print("    Stage your changes first: git add .\n", .{});
        return;
    }

    const diff = std.mem.trim(u8, diff_result.stdout, " \t\n\r");
    if (diff.len == 0) {
        std.debug.print("  ❌ No staged changes found\n", .{});
        std.debug.print("    Stage your changes first: git add .\n", .{});
        return;
    }

    std.debug.print("  🤖 Generating commit message...\n", .{});

    // Generate commit message using Ollama
    const commit_message = ollama_client.generateCommitMessage(diff) catch |err| {
        std.debug.print("  ❌ Failed to generate commit message: {}\n", .{err});
        return;
    };
    defer allocator.free(commit_message);

    const trimmed_message = std.mem.trim(u8, commit_message, " \t\n\r");

    std.debug.print("  📝 Generated: \"{s}\"\n", .{trimmed_message});
    std.debug.print("  🚀 Ready to commit!\n", .{});

    // TODO: Actually perform the commit
    // std.debug.print("  git commit -m \"{s}\"\n", .{trimmed_message});
}

fn handleExplain(ctx: flash.Context) (error{ AllocationError, AmbiguousCommand, AsyncExecutionFailed, ConfigError, HelpRequested, IOError, InvalidArgument, InvalidBoolValue, InvalidCharacter, InvalidEnumValue, InvalidFlagValue, InvalidFloatValue, InvalidInput, InvalidIntValue, MissingRequiredArgument, MissingSubcommand, OperationCancelled, OutOfMemory, Overflow, TooFewArguments, TooManyArguments, UnknownCommand, UnknownFlag, ValidationError, VersionRequested })!void {
    _ = ctx;
    std.debug.print("📖 Explaining changes\n", .{});
    std.debug.print("  🤖 Analyzing diff...\n", .{});
}

fn handleDetectAI(ctx: flash.Context) (error{ AllocationError, AmbiguousCommand, AsyncExecutionFailed, ConfigError, HelpRequested, IOError, InvalidArgument, InvalidBoolValue, InvalidCharacter, InvalidEnumValue, InvalidFlagValue, InvalidFloatValue, InvalidInput, InvalidIntValue, MissingRequiredArgument, MissingSubcommand, OperationCancelled, OutOfMemory, Overflow, TooFewArguments, TooManyArguments, UnknownCommand, UnknownFlag, ValidationError, VersionRequested })!void {
    _ = ctx;
    std.debug.print("🔍 Detecting AI assistant usage...\n", .{});

    // Use our AI detection module
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const detection = zap.ai_detect.detectRecentAIUsage(allocator) catch |err| {
        std.debug.print("  Error detecting AI: {}\n", .{err});
        return;
    };
    std.debug.print("  Assistant: {s}\n", .{@tagName(detection.assistant)});
    std.debug.print("  Confidence: {d:.2}\n", .{detection.confidence});
    std.debug.print("  Evidence: {s}\n", .{detection.evidence});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
