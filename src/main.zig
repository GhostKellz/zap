const std = @import("std");
const flash = @import("flash");
const flare = @import("flare");
const zap = @import("zap");
const commit_memory = zap.commit_memory;

// Task types for model routing
const TaskType = enum {
    commit_message,
    code_explanation,
    code_review,
    merge_assistance,
};

// Configuration structure
const ZapConfig = struct {
    ai_enabled: bool = true,
    remember_patterns: bool = true,
    max_patterns: usize = 100,
    ollama_host: []const u8 = "http://localhost:11434",
    ollama_model: []const u8 = "deepseek-coder:33b",
    ollama_timeout_ms: u32 = 30000,
};

/// Select the best AI model for a given task type
fn selectModelForTask(config: *const flare.Config, task_type: TaskType) []const u8 {
    // Try task-specific model first, fall back to default
    const model_key = switch (task_type) {
        .commit_message => "ollama.models.commit",
        .code_explanation => "ollama.models.explain",
        .code_review => "ollama.models.review",
        .merge_assistance => "ollama.models.merge",
    };

    return @constCast(config).getString(model_key, @constCast(config).getString("ollama.model", "deepseek-coder:33b") catch "deepseek-coder:33b") catch
           @constCast(config).getString("ollama.model", "deepseek-coder:33b") catch "deepseek-coder:33b";
}

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

    const changelog_cmd = flash.Command.init("changelog", (flash.CommandConfig{})
        .withAbout("Generate release notes from commit history")
        .withHandler(handleChangelog));

    const merge_cmd = flash.Command.init("merge", (flash.CommandConfig{})
        .withAbout("Assist with merge conflicts")
        .withHandler(handleMerge));

    const detect_cmd = flash.Command.init("detect-ai", (flash.CommandConfig{})
        .withAbout("Detect AI assistant usage")
        .withHandler(handleDetectAI));

    const guard_cmd = flash.Command.init("guard", (flash.CommandConfig{})
        .withAbout("Pre-commit policy checks")
        .withHandler(handleGuard));

    const review_cmd = flash.Command.init("review", (flash.CommandConfig{})
        .withAbout("AI-assisted code review")
        .withHandler(handleReview));

    const sync_cmd = flash.Command.init("sync", (flash.CommandConfig{})
        .withAbout("Safe repository synchronization")
        .withHandler(handleSync));

    const root_config = (flash.CommandConfig{})
        .withSubcommands(&[_]flash.Command{ commit_cmd, explain_cmd, changelog_cmd, merge_cmd, detect_cmd, guard_cmd, review_cmd, sync_cmd });

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
    _ = ctx; // TODO: Parse command line arguments
    // TODO: Parse command line arguments for --dry-run and --all
    const dry_run = false; // ctx.getBool("dry-run") catch false;
    const stage_all = false; // ctx.getBool("all") catch false;
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

    const ai_enabled = config.getBool("zap.ai_enabled", true) catch true;
    const ollama_host = config.getString("ollama.host", "http://localhost:11434") catch "http://localhost:11434";
    const ollama_timeout_ms = config.getInt("ollama.timeout_ms", 30000) catch 30000;

    if (!ai_enabled) {
        std.debug.print("  ❌ AI is disabled in configuration\n", .{});
        return;
    }

    // Initialize Ollama client with task-specific model
    const task_model = selectModelForTask(&config, .commit_message);
    const ollama_config = zap.ollama.OllamaConfig{
        .host = ollama_host,
        .model = task_model,
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

    // Stage all changes if --all flag is used
    if (stage_all) {
        std.debug.print("  📦 Staging all changes...\n", .{});
        const add_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "add", "." },
        }) catch |err| {
            std.debug.print("  ❌ Failed to stage changes: {}\n", .{err});
            return;
        };
        defer allocator.free(add_result.stdout);
        defer allocator.free(add_result.stderr);

        if (add_result.term != .Exited or add_result.term.Exited != 0) {
            std.debug.print("  ❌ Failed to stage changes: {s}\n", .{add_result.stderr});
            return;
        }
    }

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

        // Check for unstaged changes and suggest staging patterns
        const status_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "status", "--porcelain" },
        }) catch |err| {
            std.debug.print("    Could not check for unstaged changes: {}\n", .{err});
            std.debug.print("    Stage your changes first: git add .\n", .{});
            return;
        };
        defer allocator.free(status_result.stdout);
        defer allocator.free(status_result.stderr);

        const status = std.mem.trim(u8, status_result.stdout, " \t\n\r");
        if (status.len > 0) {
            std.debug.print("  📝 Found unstaged changes\n", .{});

            // Extract modified files for pattern suggestions
            var modified_files = std.ArrayListUnmanaged([]const u8){};
            defer {
                for (modified_files.items) |file| {
                    allocator.free(file);
                }
                modified_files.deinit(allocator);
            }

            var lines = std.mem.splitScalar(u8, status, '\n');
            while (lines.next()) |line| {
                const trimmed = std.mem.trim(u8, line, " \t");
                if (trimmed.len >= 2) {
                    // Extract filename (skip status codes)
                    const filename = std.mem.trim(u8, trimmed[2..], " \t");
                    if (filename.len > 0) {
                        try modified_files.append(allocator, try allocator.dupe(u8, filename));
                    }
                }
            }

            if (modified_files.items.len > 0) {
                // Load commit memory and suggest patterns
                var commit_mem = commit_memory.CommitMemory.init(allocator);
                defer commit_mem.deinit();

                const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch "/tmp";
                const zap_dir = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zap" });
                defer allocator.free(zap_dir);

                commit_mem.loadFromDisk(zap_dir) catch {}; // Ignore errors

                // Try to detect current AI assistant (this is a simple heuristic)
                const ai_assistant = zap.ai_detect.AIAssistant.unknown; // TODO: Better detection

                const suggestion = commit_mem.suggestStagingPattern(ai_assistant, modified_files.items) catch null;
                if (suggestion) |sugg| {
                    defer allocator.free(sugg);
                    std.debug.print("  💡 Pattern suggestion: {s}\n", .{sugg});
                }
            }
        }

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

    if (dry_run) {
        std.debug.print("  � Dry run mode - not committing\n", .{});
        return;
    }

    std.debug.print("  🚀 Committing changes...\n", .{});

    // Perform the actual git commit
    const commit_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "commit", "-m", trimmed_message },
    }) catch |err| {
        std.debug.print("  ❌ Failed to commit: {}\n", .{err});
        return;
    };
    defer allocator.free(commit_result.stdout);
    defer allocator.free(commit_result.stderr);

    if (commit_result.term != .Exited or commit_result.term.Exited != 0) {
        std.debug.print("  ❌ Commit failed: {s}\n", .{commit_result.stderr});
        return;
    }

    std.debug.print("  ✅ Successfully committed!\n", .{});

    // Pattern learning: remember successful commit patterns
    const remember_patterns = config.getBool("zap.remember_patterns", true) catch true;
    if (remember_patterns) {
        std.debug.print("  🧠 Learning from this commit...\n", .{});

        // Detect AI assistant from commit message
        const ai_detection = zap.ai_detect.detectFromCommitMessage(trimmed_message);

        // Extract file types from staged files (we need to get them again)
        const staged_files_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "diff", "--cached", "--name-only" },
        }) catch {
            std.debug.print("  ⚠️  Could not extract file types for pattern learning\n", .{});
            return;
        };
        defer allocator.free(staged_files_result.stdout);
        defer allocator.free(staged_files_result.stderr);

        const staged_files_output = std.mem.trim(u8, staged_files_result.stdout, " \t\n\r");
        var staged_files_list = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (staged_files_list.items) |file| {
                allocator.free(file);
            }
            staged_files_list.deinit(allocator);
        }

        var file_lines = std.mem.splitScalar(u8, staged_files_output, '\n');
        while (file_lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len > 0) {
                try staged_files_list.append(allocator, try allocator.dupe(u8, trimmed));
            }
        }

        const file_types = try commit_memory.extractFileTypes(allocator, staged_files_list.items);
        defer allocator.free(file_types);

        // Create commit pattern
        const pattern = commit_memory.CommitPattern{
            .ai_assistant = ai_detection.assistant,
            .staging_pattern = try std.fmt.allocPrint(allocator, "staged {d} files: {s}", .{
                staged_files_list.items.len,
                if (staged_files_list.items.len > 0) staged_files_list.items[0] else "unknown"
            }),
            .commit_message = try allocator.dupe(u8, trimmed_message),
            .success_score = 0.9, // High score for successful commits
            .timestamp = blk: {
                const ts = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch break :blk 0;
                break :blk ts.sec;
            },
            .file_types = file_types,
        };
        defer allocator.free(pattern.staging_pattern);
        defer allocator.free(pattern.commit_message);

        // Initialize commit memory
        var commit_mem = commit_memory.CommitMemory.init(allocator);
        defer commit_mem.deinit();

        // Load existing patterns
        const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch "/tmp";
        const zap_dir = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zap" });
        defer allocator.free(home_dir);
        defer allocator.free(zap_dir);

        commit_mem.loadFromDisk(zap_dir) catch |err| {
            std.debug.print("  ⚠️  Could not load existing patterns: {}\n", .{err});
        };

        // Remember this pattern
        commit_mem.rememberPattern(pattern) catch |err| {
            std.debug.print("  ⚠️  Could not remember pattern: {}\n", .{err});
        };

        // Save patterns
        commit_mem.saveToDisk(zap_dir) catch |err| {
            std.debug.print("  ⚠️  Could not save patterns: {}\n", .{err});
        };

        std.debug.print("  ✅ Pattern learned: {s} assistant, {d} file types\n", .{
            @tagName(ai_detection.assistant),
            file_types.len
        });
    }
}

fn handleExplain(ctx: flash.Context) (error{ AllocationError, AmbiguousCommand, AsyncExecutionFailed, ConfigError, HelpRequested, IOError, InvalidArgument, InvalidBoolValue, InvalidCharacter, InvalidEnumValue, InvalidFlagValue, InvalidFloatValue, InvalidInput, InvalidIntValue, MissingRequiredArgument, MissingSubcommand, OperationCancelled, OutOfMemory, Overflow, TooFewArguments, TooManyArguments, UnknownCommand, UnknownFlag, ValidationError, VersionRequested })!void {
    _ = ctx; // TODO: Parse arguments for range/file
    std.debug.print("📖 Explaining changes\n", .{});

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
        config = try flare.Config.init(allocator);
    }
    defer config.deinit();

    const ai_enabled = config.getBool("zap.ai_enabled", true) catch true;
    const ollama_host = config.getString("ollama.host", "http://localhost:11434") catch "http://localhost:11434";
    const ollama_model = selectModelForTask(&config, .code_explanation);

    if (!ai_enabled) {
        std.debug.print("  ❌ AI is disabled in configuration\n", .{});
        return;
    }

    // Initialize Ollama client
    const ollama_config = zap.ollama.OllamaConfig{
        .host = ollama_host,
        .model = ollama_model,
        .timeout_ms = 30000,
    };

    var ollama_client = zap.ollama.OllamaClient.init(allocator, ollama_config) catch |err| {
        std.debug.print("  ❌ Failed to initialize Ollama client: {}\n", .{err});
        return;
    };

    // Check if Ollama is available
    const available = ollama_client.ping() catch false;
    if (!available) {
        std.debug.print("  ❌ Ollama is not available at {s}\n", .{ollama_host});
        return;
    }

    // TODO: Parse command line arguments for commit range (default: HEAD~1..HEAD)
    const commit_range = "HEAD~1..HEAD";

    std.debug.print("  📊 Analyzing commit range: {s}\n", .{commit_range});

    // Get git log with diff for the range
    const git_cmd = try std.fmt.allocPrint(allocator, "git log --oneline --no-merges {s}", .{commit_range});
    defer allocator.free(git_cmd);

    const log_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", git_cmd },
    }) catch |err| {
        std.debug.print("  ❌ Failed to get git log: {}\n", .{err});
        return;
    };
    defer allocator.free(log_result.stdout);
    defer allocator.free(log_result.stderr);

    if (log_result.term != .Exited or log_result.term.Exited != 0) {
        std.debug.print("  ❌ No commits found in range {s}\n", .{commit_range});
        return;
    }

    const log_output = std.mem.trim(u8, log_result.stdout, " \t\n\r");
    if (log_output.len == 0) {
        std.debug.print("  ❌ No commits found in range {s}\n", .{commit_range});
        return;
    }

    // Get the diff for the range
    const diff_cmd = try std.fmt.allocPrint(allocator, "git diff {s}", .{commit_range});
    defer allocator.free(diff_cmd);

    const diff_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", diff_cmd },
    }) catch |err| {
        std.debug.print("  ❌ Failed to get git diff: {}\n", .{err});
        return;
    };
    defer allocator.free(diff_result.stdout);
    defer allocator.free(diff_result.stderr);

    const diff_output = std.mem.trim(u8, diff_result.stdout, " \t\n\r");

    // Combine log and diff for explanation
    const combined_content = try std.fmt.allocPrint(allocator,
        \\Commit log:
        \\{s}
        \\
        \\Diff:
        \\{s}
    , .{ log_output, diff_output });
    defer allocator.free(combined_content);

    std.debug.print("  🤖 Generating explanation...\n", .{});

    // Create explanation prompt
    const prompt = try std.fmt.allocPrint(allocator,
        \\Explain the following git changes in plain English. Focus on what was changed, why it might matter, and any potential impacts. Be concise but informative.
        \\
        \\{s}
    , .{combined_content});
    defer allocator.free(prompt);

    const request = zap.ollama.GenerateRequest{
        .model = ollama_model,
        .prompt = prompt,
        .stream = false,
        .options = .{
            .num_predict = 500,
            .temperature = 0.3,
        },
    };

    const explanation = ollama_client.generate(request) catch |err| {
        std.debug.print("  ❌ Failed to generate explanation: {}\n", .{err});
        return;
    };
    defer allocator.free(explanation);

    const trimmed_explanation = std.mem.trim(u8, explanation, " \t\n\r");

    std.debug.print("\n📖 Explanation:\n{s}\n", .{trimmed_explanation});
}

fn handleChangelog(ctx: flash.Context) (error{ AllocationError, AmbiguousCommand, AsyncExecutionFailed, ConfigError, HelpRequested, IOError, InvalidArgument, InvalidBoolValue, InvalidCharacter, InvalidEnumValue, InvalidFlagValue, InvalidFloatValue, InvalidInput, InvalidIntValue, MissingRequiredArgument, MissingSubcommand, OperationCancelled, OutOfMemory, Overflow, TooFewArguments, TooManyArguments, UnknownCommand, UnknownFlag, ValidationError, VersionRequested })!void {
    _ = ctx; // TODO: Parse arguments for version range
    std.debug.print("📋 Generating changelog\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // TODO: Parse command line arguments for version range (default: last tag..HEAD)
    const version_range = "--all"; // Get all commits for demo

    std.debug.print("  📊 Analyzing commits: {s}\n", .{version_range});

    // Get git log with conventional commit format
    const git_cmd = try std.fmt.allocPrint(allocator,
        \\git log --oneline --no-merges {s}
    , .{version_range});
    defer allocator.free(git_cmd);

    const log_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", git_cmd },
    }) catch |err| {
        std.debug.print("  ❌ Failed to get git log: {}\n", .{err});
        return;
    };
    defer allocator.free(log_result.stdout);
    defer allocator.free(log_result.stderr);

    if (log_result.term != .Exited or log_result.term.Exited != 0) {
        std.debug.print("  ❌ No conventional commits found in range {s}\n", .{version_range});
        std.debug.print("    Try a different range or ensure commits follow conventional format\n", .{});
        return;
    }

    const log_output = std.mem.trim(u8, log_result.stdout, " \t\n\r");
    if (log_output.len == 0) {
        std.debug.print("  ❌ No conventional commits found in range {s}\n", .{version_range});
        return;
    }

    std.debug.print("  📝 Processing commits...\n", .{});

    // Parse commits by type
    var features = std.ArrayListUnmanaged([]const u8){};
    defer features.deinit(allocator);
    var fixes = std.ArrayListUnmanaged([]const u8){};
    defer fixes.deinit(allocator);
    var docs = std.ArrayListUnmanaged([]const u8){};
    defer docs.deinit(allocator);
    var other = std.ArrayListUnmanaged([]const u8){};
    defer other.deinit(allocator);

    var lines = std.mem.splitScalar(u8, log_output, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (trimmed.len == 0) continue;

        // Extract commit message (skip hash)
        const space_index = std.mem.indexOf(u8, trimmed, " ") orelse continue;
        var message = trimmed[space_index + 1..];

        // Strip surrounding quotes if present
        if (message.len >= 2 and message[0] == '"' and message[message.len - 1] == '"') {
            message = message[1..message.len - 1];
        }

        if (std.mem.startsWith(u8, message, "feat")) {
            try features.append(allocator, message);
        } else if (std.mem.startsWith(u8, message, "fix")) {
            try fixes.append(allocator, message);
        } else if (std.mem.startsWith(u8, message, "docs")) {
            try docs.append(allocator, message);
        } else {
            try other.append(allocator, message);
        }
    }

    // Generate changelog
    std.debug.print("\n📋 Changelog\n", .{});
    std.debug.print("==========\n\n", .{});

    if (features.items.len > 0) {
        std.debug.print("## ✨ Features\n\n", .{});
        for (features.items) |feat| {
            std.debug.print("- {s}\n", .{feat});
        }
        std.debug.print("\n", .{});
    }

    if (fixes.items.len > 0) {
        std.debug.print("## 🐛 Fixes\n\n", .{});
        for (fixes.items) |fix| {
            std.debug.print("- {s}\n", .{fix});
        }
        std.debug.print("\n", .{});
    }

    if (docs.items.len > 0) {
        std.debug.print("## 📚 Documentation\n\n", .{});
        for (docs.items) |doc| {
            std.debug.print("- {s}\n", .{doc});
        }
        std.debug.print("\n", .{});
    }

    if (other.items.len > 0) {
        std.debug.print("## 🔧 Other Changes\n\n", .{});
        for (other.items) |change| {
            std.debug.print("- {s}\n", .{change});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("---\n", .{});
    std.debug.print("Generated from {d} commits\n", .{features.items.len + fixes.items.len + docs.items.len + other.items.len});
}

fn handleMerge(ctx: flash.Context) (error{ AllocationError, AmbiguousCommand, AsyncExecutionFailed, ConfigError, HelpRequested, IOError, InvalidArgument, InvalidBoolValue, InvalidCharacter, InvalidEnumValue, InvalidFlagValue, InvalidFloatValue, InvalidInput, InvalidIntValue, MissingRequiredArgument, MissingSubcommand, OperationCancelled, OutOfMemory, Overflow, TooFewArguments, TooManyArguments, UnknownCommand, UnknownFlag, ValidationError, VersionRequested })!void {
    _ = ctx; // TODO: Parse arguments for --assist flag
    std.debug.print("🔀 Merge conflict assistance\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Check if we're in a merge state
    const merge_head_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "rev-parse", "--verify", "MERGE_HEAD" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to check merge state: {}\n", .{err});
        return;
    };
    defer allocator.free(merge_head_result.stdout);
    defer allocator.free(merge_head_result.stderr);

    const in_merge = merge_head_result.term == .Exited and merge_head_result.term.Exited == 0;

    if (!in_merge) {
        std.debug.print("  ℹ️  No active merge in progress\n", .{});
        std.debug.print("    Start a merge first: git merge <branch>\n", .{});
        return;
    }

    std.debug.print("  🔍 Detecting conflicts...\n", .{});

    // Get status to find conflicted files
    const status_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "status", "--porcelain" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to get git status: {}\n", .{err});
        return;
    };
    defer allocator.free(status_result.stdout);
    defer allocator.free(status_result.stderr);

    if (status_result.term != .Exited or status_result.term.Exited != 0) {
        std.debug.print("  ❌ Failed to get git status\n", .{});
        return;
    }

    // Parse conflicted files (files starting with 'UU' or 'AA' etc.)
    var conflicted_files = std.ArrayListUnmanaged([]const u8){};
    defer conflicted_files.deinit(allocator);

    var status_lines = std.mem.splitScalar(u8, status_result.stdout, '\n');
    while (status_lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (trimmed.len < 3) continue;

        // Check for conflict indicators
        const status_code = trimmed[0..2];
        if (std.mem.eql(u8, status_code, "UU") or
            std.mem.eql(u8, status_code, "AA") or
            std.mem.eql(u8, status_code, "DD")) {

            const filename = std.mem.trim(u8, trimmed[3..], " \t");
            try conflicted_files.append(allocator, try allocator.dupe(u8, filename));
        }
    }

    if (conflicted_files.items.len == 0) {
        std.debug.print("  ✅ No conflicts detected!\n", .{});
        std.debug.print("    You can complete the merge: git commit\n", .{});
        return;
    }

    std.debug.print("  ⚠️  Found {d} conflicted file{s}:\n", .{
        conflicted_files.items.len,
        if (conflicted_files.items.len == 1) "" else "s"
    });

    for (conflicted_files.items) |file| {
        std.debug.print("    - {s}\n", .{file});
    }

    std.debug.print("\n  🤖 Analyzing conflicts...\n", .{});

    // Load configuration for AI assistance
    var config: flare.Config = undefined;
    const config_result = loadConfig(allocator);
    if (config_result) |cfg| {
        config = cfg;
    } else |err| {
        std.debug.print("Warning: Failed to load config: {}\n", .{err});
        config = try flare.Config.init(allocator);
    }
    defer config.deinit();

    const ai_enabled = config.getBool("zap.ai_enabled", true) catch true;
    const ollama_host = config.getString("ollama.host", "http://localhost:11434") catch "http://localhost:11434";
    const ollama_model = selectModelForTask(&config, .merge_assistance);

    if (!ai_enabled) {
        std.debug.print("  ❌ AI is disabled in configuration\n", .{});
        std.debug.print("    Resolve conflicts manually or enable AI assistance\n", .{});
        return;
    }

    // Initialize Ollama client
    const ollama_config = zap.ollama.OllamaConfig{
        .host = ollama_host,
        .model = ollama_model,
        .timeout_ms = 30000,
    };

    var ollama_client = zap.ollama.OllamaClient.init(allocator, ollama_config) catch |err| {
        std.debug.print("  ❌ Failed to initialize Ollama client: {}\n", .{err});
        return;
    };

    // Check if Ollama is available
    const available = ollama_client.ping() catch false;
    if (!available) {
        std.debug.print("  ❌ Ollama is not available at {s}\n", .{ollama_host});
        return;
    }

    // Analyze first conflicted file as an example
    if (conflicted_files.items.len > 0) {
        const first_file = conflicted_files.items[0];
        std.debug.print("  📄 Analyzing: {s}\n", .{first_file});

        // Get conflicted file content using git show
        const show_cmd = try std.fmt.allocPrint(allocator,
            \\git show :1:{s}
        , .{first_file});
        defer allocator.free(show_cmd);

        const show_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "sh", "-c", show_cmd },
        }) catch |err| {
            std.debug.print("  ❌ Failed to get file content: {}\n", .{err});
            return;
        };
        defer allocator.free(show_result.stdout);
        defer allocator.free(show_result.stderr);

        const file_content = std.mem.trim(u8, show_result.stdout, " \t\n\r");

        // Count conflict markers
        var conflict_count: usize = 0;
        var lines = std.mem.splitScalar(u8, file_content, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "<<<<<<< ") or
                std.mem.startsWith(u8, line, "=======") or
                std.mem.startsWith(u8, line, ">>>>>>> ")) {
                conflict_count += 1;
            }
        }

        std.debug.print("  🔍 Found {d} conflict marker{s}\n", .{
            conflict_count / 3, // Each conflict has 3 markers
            if (conflict_count / 3 == 1) "" else "s"
        });

        // Get diff information for context
        const diff_cmd = try std.fmt.allocPrint(allocator,
            \\git diff HEAD MERGE_HEAD -- {s}
        , .{first_file});
        defer allocator.free(diff_cmd);

        const diff_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "sh", "-c", diff_cmd },
        }) catch |err| {
            std.debug.print("  ❌ Failed to get diff: {}\n", .{err});
            return;
        };
        defer allocator.free(diff_result.stdout);
        defer allocator.free(diff_result.stderr);

        const diff_content = std.mem.trim(u8, diff_result.stdout, " \t\n\r");

        // Create analysis prompt
        const prompt = try std.fmt.allocPrint(allocator,
            \\Analyze this merge conflict and provide resolution guidance. Focus on:
            \\1. What changes are conflicting
            \\2. Why they conflict
            \\3. Suggested resolution approach
            \\4. Risk assessment
            \\
            \\File: {s}
            \\Conflict markers found: {d}
            \\
            \\Diff context:
            \\{s}
            \\
            \\Conflicted file content (first 500 chars):
            \\{s}
        , .{
            first_file,
            conflict_count / 3,
            diff_content,
            if (file_content.len > 500) file_content[0..500] else file_content
        });
        defer allocator.free(prompt);

        const request = zap.ollama.GenerateRequest{
            .model = ollama_model,
            .prompt = prompt,
            .stream = false,
            .options = .{
                .num_predict = 800,
                .temperature = 0.2,
            },
        };

        const analysis = ollama_client.generate(request) catch |err| {
            std.debug.print("  ❌ Failed to analyze conflict: {}\n", .{err});
            return;
        };
        defer allocator.free(analysis);

        const trimmed_analysis = std.mem.trim(u8, analysis, " \t\n\r");

        std.debug.print("\n🤖 Conflict Analysis:\n{s}\n", .{trimmed_analysis});
    }

    std.debug.print("\n💡 Next steps:\n", .{});
    std.debug.print("  1. Edit conflicted files and remove conflict markers\n", .{});
    std.debug.print("  2. Stage resolved files: git add <file>\n", .{});
    std.debug.print("  3. Complete merge: git commit\n", .{});
    std.debug.print("  4. Or abort merge: git merge --abort\n", .{});
}

fn handleGuard(ctx: flash.Context) (error{ AllocationError, AmbiguousCommand, AsyncExecutionFailed, ConfigError, HelpRequested, IOError, InvalidArgument, InvalidBoolValue, InvalidCharacter, InvalidEnumValue, InvalidFlagValue, InvalidFloatValue, InvalidInput, InvalidIntValue, MissingRequiredArgument, MissingSubcommand, OperationCancelled, OutOfMemory, Overflow, TooFewArguments, TooManyArguments, UnknownCommand, UnknownFlag, ValidationError, VersionRequested })!void {
    _ = ctx; // TODO: Parse arguments for --fix flag
    std.debug.print("🛡️  Pre-commit policy checks\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load configuration for policy settings
    var config: flare.Config = undefined;
    const config_result = loadConfig(allocator);
    if (config_result) |cfg| {
        config = cfg;
    } else |err| {
        std.debug.print("Warning: Failed to load config: {}\n", .{err});
        config = try flare.Config.init(allocator);
    }
    defer config.deinit();

    // Get staged files
    const diff_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "diff", "--cached", "--name-only" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to get staged files: {}\n", .{err});
        return;
    };
    defer allocator.free(diff_result.stdout);
    defer allocator.free(diff_result.stderr);

    if (diff_result.term != .Exited or diff_result.term.Exited != 0) {
        std.debug.print("  ❌ Failed to get staged files\n", .{});
        return;
    }

    const staged_files_output = std.mem.trim(u8, diff_result.stdout, " \t\n\r");
    if (staged_files_output.len == 0) {
        std.debug.print("  ℹ️  No staged files to check\n", .{});
        std.debug.print("    Stage your changes first: git add .\n", .{});
        return;
    }

    // Parse staged files
    var staged_files = std.ArrayListUnmanaged([]const u8){};
    defer {
        for (staged_files.items) |file| {
            allocator.free(file);
        }
        staged_files.deinit(allocator);
    }

    var file_lines = std.mem.splitScalar(u8, staged_files_output, '\n');
    while (file_lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (trimmed.len > 0) {
            try staged_files.append(allocator, try allocator.dupe(u8, trimmed));
        }
    }

    std.debug.print("  📁 Checking {d} staged file{s}\n", .{
        staged_files.items.len,
        if (staged_files.items.len == 1) "" else "s"
    });

    var issues_found: usize = 0;
    var secrets_found: usize = 0;
    var todos_found: usize = 0;
    var license_issues: usize = 0;

    // Check each file
    for (staged_files.items) |file| {
        std.debug.print("    Checking: {s}\n", .{file});

        // Get file content
        const show_cmd = try std.fmt.allocPrint(allocator,
            \\git show :0:{s}
        , .{file});
        defer allocator.free(show_cmd);

        const show_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "sh", "-c", show_cmd },
        }) catch |err| {
            std.debug.print("      ❌ Failed to read file: {}\n", .{err});
            continue;
        };
        defer allocator.free(show_result.stdout);
        defer allocator.free(show_result.stderr);

        const file_content = std.mem.trim(u8, show_result.stdout, " \t\n\r");

        // Check for secrets (API keys, passwords, etc.)
        const secret_patterns = [_][]const u8{
            "password[\\s]*[=:][\\s]*[\\w]+",
            "api[_-]?key[\\s]*[=:][\\s]*[\\w]+",
            "secret[\\s]*[=:][\\s]*[\\w]+",
            "token[\\s]*[=:][\\s]*[\\w]+",
            "PRIVATE[_\\s]?KEY[\\s]*[=:][\\s]*[\\w]+",
        };

        for (secret_patterns) |pattern| {
            if (std.mem.indexOf(u8, file_content, pattern)) |_| {
                std.debug.print("      ⚠️  Potential secret found: {s}\n", .{pattern});
                secrets_found += 1;
                issues_found += 1;
            }
        }

        // Check for TODOs/FIXMEs
        const todo_patterns = [_][]const u8{ "TODO", "FIXME", "XXX", "HACK" };
        var lines = std.mem.splitScalar(u8, file_content, '\n');
        var line_num: usize = 1;
        while (lines.next()) |line| {
            for (todo_patterns) |todo| {
                if (std.mem.indexOf(u8, line, todo)) |_| {
                    std.debug.print("      📝 TODO found at line {d}: {s}\n", .{line_num, std.mem.trim(u8, line, " \t")});
                    todos_found += 1;
                    issues_found += 1;
                    break;
                }
            }
            line_num += 1;
        }

        // Check license headers (basic check)
        const has_license = std.mem.indexOf(u8, file_content, "Copyright") != null or
                           std.mem.indexOf(u8, file_content, "License") != null or
                           std.mem.indexOf(u8, file_content, "MIT") != null or
                           std.mem.indexOf(u8, file_content, "Apache") != null or
                           std.mem.indexOf(u8, file_content, "GPL") != null;

        if (!has_license and std.mem.endsWith(u8, file, ".zig")) {
            std.debug.print("      📄 Missing license header\n", .{});
            license_issues += 1;
            issues_found += 1;
        }
    }

    // Summary
    std.debug.print("\n📊 Policy Check Results:\n", .{});
    std.debug.print("  🔍 Files checked: {d}\n", .{staged_files.items.len});
    std.debug.print("  ⚠️  Issues found: {d}\n", .{issues_found});

    if (issues_found > 0) {
        std.debug.print("  🚨 Blocking issues:\n", .{});
        if (secrets_found > 0) {
            std.debug.print("    - {d} potential secret{s}\n", .{secrets_found, if (secrets_found == 1) "" else "s"});
        }
        if (todos_found > 0) {
            std.debug.print("    - {d} TODO comment{s}\n", .{todos_found, if (todos_found == 1) "" else "s"});
        }
        if (license_issues > 0) {
            std.debug.print("    - {d} missing license header{s}\n", .{license_issues, if (license_issues == 1) "" else "s"});
        }

        std.debug.print("\n❌ Commit blocked by policy violations\n", .{});
        std.debug.print("   Fix the issues above or use --force to override\n", .{});
        return error.ValidationError; // Block the commit
    } else {
        std.debug.print("  ✅ All checks passed!\n", .{});
        std.debug.print("    Ready to commit: git commit\n", .{});
    }
}

fn handleReview(ctx: flash.Context) (error{ AllocationError, AmbiguousCommand, AsyncExecutionFailed, ConfigError, HelpRequested, IOError, InvalidArgument, InvalidBoolValue, InvalidCharacter, InvalidEnumValue, InvalidFlagValue, InvalidFloatValue, InvalidInput, InvalidIntValue, MissingRequiredArgument, MissingSubcommand, OperationCancelled, OutOfMemory, Overflow, TooFewArguments, TooManyArguments, UnknownCommand, UnknownFlag, ValidationError, VersionRequested })!void {
    _ = ctx; // TODO: Parse arguments for --range, --file, --comprehensive
    std.debug.print("🔍 AI-assisted code review\n", .{});

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
        config = try flare.Config.init(allocator);
    }
    defer config.deinit();

    const ai_enabled = config.getBool("zap.ai_enabled", true) catch true;
    const ollama_host = config.getString("ollama.host", "http://localhost:11434") catch "http://localhost:11434";
    const ollama_model = selectModelForTask(&config, .code_review);

    if (!ai_enabled) {
        std.debug.print("  ❌ AI is disabled in configuration\n", .{});
        return;
    }

    // Get current changes (staged + unstaged)
    const diff_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "diff", "HEAD" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to get diff: {}\n", .{err});
        return;
    };
    defer allocator.free(diff_result.stdout);
    defer allocator.free(diff_result.stderr);

    if (diff_result.term != .Exited or diff_result.term.Exited != 0) {
        std.debug.print("  ❌ Failed to get diff\n", .{});
        return;
    }

    const diff = std.mem.trim(u8, diff_result.stdout, " \t\n\r");
    if (diff.len == 0) {
        std.debug.print("  ℹ️  No changes to review\n", .{});
        std.debug.print("    Make some changes first or specify a commit range\n", .{});
        return;
    }

    // Limit diff size for AI processing (first 10KB should be enough for review)
    const max_diff_size = 10 * 1024;
    const truncated_diff = if (diff.len > max_diff_size) diff[0..max_diff_size] else diff;

    std.debug.print("  📊 Analyzing changes...\n", .{});

    // Count changed files and lines
    var file_count: usize = 0;
    var addition_count: usize = 0;
    var deletion_count: usize = 0;

    var diff_lines = std.mem.splitScalar(u8, diff, '\n');
    while (diff_lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "+++ ")) {
            file_count += 1;
        } else if (std.mem.startsWith(u8, line, "+") and !std.mem.startsWith(u8, line, "+++")) {
            addition_count += 1;
        } else if (std.mem.startsWith(u8, line, "-") and !std.mem.startsWith(u8, line, "---")) {
            deletion_count += 1;
        }
    }

    std.debug.print("  📁 Files changed: {d}\n", .{file_count});
    std.debug.print("  ➕ Lines added: {d}\n", .{addition_count});
    std.debug.print("  ➖ Lines removed: {d}\n", .{deletion_count});

    // Initialize Ollama client
    const ollama_config = zap.ollama.OllamaConfig{
        .host = ollama_host,
        .model = ollama_model,
        .timeout_ms = 30000,
    };

    var ollama_client = zap.ollama.OllamaClient.init(allocator, ollama_config) catch |err| {
        std.debug.print("  ❌ Failed to initialize Ollama client: {}\n", .{err});
        return;
    };

    // Check if Ollama is available
    const available = ollama_client.ping() catch false;
    if (!available) {
        std.debug.print("  ❌ Ollama is not available at {s}\n", .{ollama_host});
        return;
    }

    std.debug.print("  🤖 Generating review...\n", .{});

    // Create review prompt (simplified for testing)
    const prompt = try std.fmt.allocPrint(allocator,
        \\Review this code change briefly. Focus on major issues.
        \\
        \\Diff summary: {d} files changed, +{d}/-{d} lines
        \\
        \\Diff content:
        \\{s}
    , .{
        file_count, addition_count, deletion_count,
        truncated_diff
    });
    std.debug.print("DEBUG: Prompt length: {d}\n", .{prompt.len});
    std.debug.print("DEBUG: Prompt preview: {s}...\n", .{if (prompt.len > 100) prompt[0..100] else prompt});
    std.debug.print("DEBUG: Truncated diff preview: {s}...\n", .{if (truncated_diff.len > 50) truncated_diff[0..50] else truncated_diff});
    defer allocator.free(prompt);

    const request = zap.ollama.GenerateRequest{
        .model = ollama_model,
        .prompt = prompt,
        .stream = false,
        .options = .{
            .num_predict = 200,  // Reduced from 500
            .temperature = 0.3,
        },
    };

    const review = ollama_client.generate(request) catch |err| {
        std.debug.print("  ❌ Failed to generate review: {}\n", .{err});
        return;
    };
    defer allocator.free(review);

    const trimmed_review = std.mem.trim(u8, review, " \t\n\r");

    std.debug.print("\n🔍 Code Review:\n{s}\n", .{trimmed_review});

    // Summary
    std.debug.print("\n📋 Review Summary:\n", .{});
    std.debug.print("  📊 Changes analyzed: {d} files, +{d}/-{d} lines\n", .{
        file_count, addition_count, deletion_count
    });
    std.debug.print("  🤖 AI model used: {s}\n", .{ollama_model});
    std.debug.print("  ✅ Review completed\n", .{});
}

fn handleSync(ctx: flash.Context) (error{ AllocationError, AmbiguousCommand, AsyncExecutionFailed, ConfigError, HelpRequested, IOError, InvalidArgument, InvalidBoolValue, InvalidCharacter, InvalidEnumValue, InvalidFlagValue, InvalidFloatValue, InvalidInput, InvalidIntValue, MissingRequiredArgument, MissingSubcommand, OperationCancelled, OutOfMemory, Overflow, TooFewArguments, TooManyArguments, UnknownCommand, UnknownFlag, ValidationError, VersionRequested })!void {
    _ = ctx; // TODO: Parse arguments for --stash, --force, --remote
    std.debug.print("🔄 Safe repository synchronization\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Check git status
    std.debug.print("  📊 Checking repository status...\n", .{});

    const status_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "status", "--porcelain" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to check git status: {}\n", .{err});
        return;
    };
    defer allocator.free(status_result.stdout);
    defer allocator.free(status_result.stderr);

    if (status_result.term != .Exited or status_result.term.Exited != 0) {
        std.debug.print("  ❌ Failed to get git status\n", .{});
        return;
    }

    const status = std.mem.trim(u8, status_result.stdout, " \t\n\r");
    const has_changes = status.len > 0;

    if (has_changes) {
        std.debug.print("  📝 Uncommitted changes detected\n", .{});
        std.debug.print("    Stashing changes for safe sync...\n", .{});

        // Stash changes
        const stash_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "stash", "push", "-m", "zap sync auto-stash" },
        }) catch |err| {
            std.debug.print("  ❌ Failed to stash changes: {}\n", .{err});
            return;
        };
        defer allocator.free(stash_result.stdout);
        defer allocator.free(stash_result.stderr);

        if (stash_result.term != .Exited or stash_result.term.Exited != 0) {
            std.debug.print("  ❌ Failed to stash changes: {s}\n", .{stash_result.stderr});
            return;
        }

        std.debug.print("  ✅ Changes stashed\n", .{});
    } else {
        std.debug.print("  ✅ Working directory clean\n", .{});
    }

    // Check if we're on a branch
    const branch_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "branch", "--show-current" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to get current branch: {}\n", .{err});
        return;
    };
    defer allocator.free(branch_result.stdout);
    defer allocator.free(branch_result.stderr);

    if (branch_result.term != .Exited or branch_result.term.Exited != 0) {
        std.debug.print("  ❌ Not on a branch\n", .{});
        return;
    }

    const branch = std.mem.trim(u8, branch_result.stdout, " \t\n\r");
    std.debug.print("  🌿 On branch: {s}\n", .{branch});

    // Check if remote exists
    const remote_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "remote", "get-url", "origin" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to check remote: {}\n", .{err});
        return;
    };
    defer allocator.free(remote_result.stdout);
    defer allocator.free(remote_result.stderr);

    const has_remote = remote_result.term == .Exited and remote_result.term.Exited == 0;

    if (!has_remote) {
        std.debug.print("  ℹ️  No remote configured\n", .{});
        std.debug.print("    Add a remote: git remote add origin <url>\n", .{});

        // Restore stashed changes if any
        if (has_changes) {
            std.debug.print("  🔄 Restoring stashed changes...\n", .{});
            const stash_pop_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "git", "stash", "pop" },
            }) catch |err| {
                std.debug.print("  ❌ Failed to restore changes: {}\n", .{err});
                return;
            };
            defer allocator.free(stash_pop_result.stdout);
            defer allocator.free(stash_pop_result.stderr);
        }

        return;
    }

    const remote_url = std.mem.trim(u8, remote_result.stdout, " \t\n\r");
    std.debug.print("  🌐 Remote: {s}\n", .{remote_url});

    // Fetch latest changes
    std.debug.print("  📥 Fetching latest changes...\n", .{});

    const fetch_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "fetch", "origin" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to fetch: {}\n", .{err});
        return;
    };
    defer allocator.free(fetch_result.stdout);
    defer allocator.free(fetch_result.stderr);

    if (fetch_result.term != .Exited or fetch_result.term.Exited != 0) {
        std.debug.print("  ❌ Failed to fetch: {s}\n", .{fetch_result.stderr});
        return;
    }

    std.debug.print("  ✅ Fetch completed\n", .{});

    // Check if we're ahead/behind
    const ahead_behind_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "rev-list", "--count", "--left-right", "HEAD...origin/main" },
    }) catch |err| {
        std.debug.print("  ❌ Failed to check ahead/behind: {}\n", .{err});
        return;
    };
    defer allocator.free(ahead_behind_result.stdout);
    defer allocator.free(ahead_behind_result.stderr);

    const ahead_behind = std.mem.trim(u8, ahead_behind_result.stdout, " \t\n\r");
    var ahead_count: usize = 0;
    var behind_count: usize = 0;

    if (ahead_behind_result.term == .Exited and ahead_behind_result.term.Exited == 0) {
        var parts = std.mem.splitScalar(u8, ahead_behind, '\t');
        if (parts.next()) |ahead| {
            ahead_count = std.fmt.parseInt(usize, ahead, 10) catch 0;
        }
        if (parts.next()) |behind| {
            behind_count = std.fmt.parseInt(usize, behind, 10) catch 0;
        }
    }

    std.debug.print("  📊 Branch status: {d} ahead, {d} behind\n", .{ahead_count, behind_count});

    // Pull if behind
    if (behind_count > 0) {
        std.debug.print("  ⬇️  Pulling {d} commits...\n", .{behind_count});

        const pull_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "pull", "--ff-only", "origin", branch },
        }) catch |err| {
            std.debug.print("  ❌ Failed to pull: {}\n", .{err});
            return;
        };
        defer allocator.free(pull_result.stdout);
        defer allocator.free(pull_result.stderr);

        if (pull_result.term != .Exited or pull_result.term.Exited != 0) {
            std.debug.print("  ❌ Failed to pull: {s}\n", .{pull_result.stderr});
            return;
        }

        std.debug.print("  ✅ Pull completed\n", .{});
    } else {
        std.debug.print("  ✅ Branch is up to date\n", .{});
    }

    // Push if ahead
    if (ahead_count > 0) {
        std.debug.print("  ⬆️  Pushing {d} commits...\n", .{ahead_count});

        const push_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "push", "origin", branch },
        }) catch |err| {
            std.debug.print("  ❌ Failed to push: {}\n", .{err});
            return;
        };
        defer allocator.free(push_result.stdout);
        defer allocator.free(push_result.stderr);

        if (push_result.term != .Exited or push_result.term.Exited != 0) {
            std.debug.print("  ❌ Failed to push: {s}\n", .{push_result.stderr});
            return;
        }

        std.debug.print("  ✅ Push completed\n", .{});
    } else {
        std.debug.print("  ✅ No commits to push\n", .{});
    }

    // Restore stashed changes if any
    if (has_changes) {
        std.debug.print("  🔄 Restoring stashed changes...\n", .{});

        const stash_pop_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "stash", "pop" },
        }) catch |err| {
            std.debug.print("  ❌ Failed to restore changes: {}\n", .{err});
            return;
        };
        defer allocator.free(stash_pop_result.stdout);
        defer allocator.free(stash_pop_result.stderr);

        if (stash_pop_result.term != .Exited or stash_pop_result.term.Exited != 0) {
            std.debug.print("  ⚠️  Failed to restore changes: {s}\n", .{stash_pop_result.stderr});
            std.debug.print("    You may need to manually restore: git stash pop\n", .{});
        } else {
            std.debug.print("  ✅ Changes restored\n", .{});
        }
    }

    std.debug.print("  🎉 Repository synchronized successfully!\n", .{});
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
