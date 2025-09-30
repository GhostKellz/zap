# ⚡ Zap Commands Reference

This document provides a comprehensive reference for all available Zap commands, their options, and usage examples.

## 📋 Command Overview

Zap provides AI-powered Git workflow enhancements with the following commands:

| Command | Description | AI-Powered |
|---------|-------------|------------|
| [`zap commit`](#zap-commit) | Generate intelligent commit messages | ✅ |
| [`zap explain`](#zap-explain) | Explain changes in plain English | ✅ |
| [`zap review`](#zap-review) | AI-assisted code review | ✅ |
| [`zap merge`](#zap-merge) | Merge conflict assistance | ✅ |
| [`zap guard`](#zap-guard) | Pre-commit policy checks | ❌ |
| [`zap sync`](#zap-sync) | Safe repository synchronization | ❌ |
| [`zap changelog`](#zap-changelog) | Generate release notes | ❌ |
| [`zap detect-ai`](#zap-detect-ai) | Detect AI assistant usage | ❌ |

---

## `zap commit`

Generate intelligent commit messages using AI analysis of your changes.

### Usage
```bash
zap commit [OPTIONS]
```

### Options
- `-a, --all` - Automatically stage all modified and deleted files
- `-m, --message <MESSAGE>` - Use provided commit message instead of AI generation
- `--dry-run` - Show what would be committed without making changes

### Examples
```bash
# Stage all changes and generate AI commit message
zap commit -a

# Generate commit message for already staged changes
zap commit

# Use custom message instead of AI generation
zap commit -m "fix: resolve authentication bug"

# Preview what would be committed
zap commit --dry-run
```

### AI Behavior
- Analyzes staged changes using the configured `ollama.models.commit` model
- Learns from your repository's commit patterns (stored in `~/.zap/`)
- Generates conventional commit format messages
- Falls back to default model if task-specific model not configured

---

## `zap explain`

Explain git changes in plain English using AI analysis.

### Usage
```bash
zap explain [RANGE] [OPTIONS]
```

### Arguments
- `RANGE` - Git revision range (default: `HEAD~1..HEAD`)

### Options
- `--file <FILE>` - Explain changes to specific file
- `--comprehensive` - Include detailed technical analysis

### Examples
```bash
# Explain last commit
zap explain

# Explain specific commit range
zap explain HEAD~3..HEAD

# Explain changes in specific file
zap explain --file src/main.zig

# Explain changes between branches
zap explain main..feature-branch

# Comprehensive analysis
zap explain --comprehensive v1.0..v2.0
```

### AI Behavior
- Uses the configured `ollama.models.explain` model for code explanation
- Analyzes git diffs and commit messages
- Provides clear, non-technical explanations of what changed and why
- Focuses on impact and potential consequences

---

## `zap review`

Perform AI-assisted code review on staged changes.

### Usage
```bash
zap review [OPTIONS]
```

### Options
- `--file <FILE>` - Review specific file instead of all staged changes
- `--comprehensive` - Include detailed analysis and suggestions
- `--focus <AREA>` - Focus review on specific areas (security, performance, style)

### Examples
```bash
# Review all staged changes
zap review

# Review specific file
zap review --file src/auth.zig

# Comprehensive review with detailed feedback
zap review --comprehensive

# Focus on security issues
zap review --focus security
```

### AI Behavior
- Uses the configured `ollama.models.review` model for code analysis
- Analyzes code quality, potential bugs, and best practices
- Detects security vulnerabilities and performance issues
- Provides actionable improvement suggestions
- Can truncate large diffs for focused analysis

---

## `zap merge`

Assist with merge conflicts using AI analysis.

### Usage
```bash
zap merge [OPTIONS]
```

### Options
- `--assist` - Provide AI suggestions for conflict resolution
- `--preview` - Show potential merge conflicts before merging
- `--strategy <STRATEGY>` - Use specific merge strategy (ours, theirs, manual)

### Examples
```bash
# Start merge with AI assistance
zap merge --assist feature-branch

# Preview conflicts before merging
zap merge --preview feature-branch

# Use specific merge strategy
zap merge --strategy ours hotfix-branch
```

### AI Behavior
- Uses the configured `ollama.models.merge` model for conflict analysis
- Detects and analyzes merge conflicts
- Provides suggested resolutions with explanations
- Explains the risks and implications of each approach
- Only activates when actual merge conflicts are present

---

## `zap guard`

Run pre-commit policy checks on staged changes.

### Usage
```bash
zap guard [OPTIONS]
```

### Options
- `--fix` - Automatically fix issues where possible
- `--strict` - Fail on warnings, not just errors
- `--skip <CHECK>` - Skip specific check types

### Checks Performed
- **Secrets Detection**: Scans for API keys, passwords, tokens
- **TODO/FIXME Comments**: Identifies incomplete work
- **License Headers**: Ensures proper copyright notices
- **Code Quality**: Basic static analysis

### Examples
```bash
# Run all policy checks
zap guard

# Automatically fix issues
zap guard --fix

# Strict mode (fail on warnings)
zap guard --strict

# Skip license checks
zap guard --skip license
```

### Configuration
Policy checks are configured in `.zap.toml`:
```toml
[policies]
block_secrets = true
require_tests_on = ["feat", "fix", "refactor"]
```

---

## `zap sync`

Perform safe repository synchronization with change preview.

### Usage
```bash
zap sync [OPTIONS]
```

### Options
- `--stash` - Stash local changes before sync
- `--force` - Force sync even with conflicts
- `--remote <REMOTE>` - Specify remote to sync with (default: origin)
- `--branch <BRANCH>` - Specify branch to sync with (default: current)

### Examples
```bash
# Safe sync with current branch
zap sync

# Sync with specific remote and branch
zap sync --remote upstream --branch main

# Stash changes before sync
zap sync --stash

# Force sync (use with caution)
zap sync --force
```

### Safety Features
- Stashes uncommitted changes automatically
- Shows preview of incoming changes
- Verifies no conflicts before applying
- Provides rollback options if needed

---

## `zap changelog`

Generate release notes from commit history.

### Usage
```bash
zap changelog [RANGE] [OPTIONS]
```

### Arguments
- `RANGE` - Commit range to analyze (default: all commits)

### Options
- `--format <FORMAT>` - Output format (markdown, json, plain)
- `--group-by <TYPE>` - Group entries by type (type, scope, author)
- `--filter <TYPE>` - Filter by commit type (feat, fix, docs, etc.)

### Examples
```bash
# Generate changelog for all commits
zap changelog

# Generate changelog since last tag
zap changelog v1.0.0..HEAD

# Filter by feature commits only
zap changelog --filter feat

# Group by commit scope
zap changelog --group-by scope

# JSON output for automation
zap changelog --format json
```

### Output Formats
- **Markdown**: Human-readable release notes
- **JSON**: Machine-readable for automation
- **Plain**: Simple text format

---

## `zap detect-ai`

Detect and analyze AI assistant usage patterns in the repository.

### Usage
```bash
zap detect-ai [OPTIONS]
```

### Options
- `--since <DATE>` - Analyze commits since date
- `--author <AUTHOR>` - Focus on specific author
- `--detailed` - Show detailed analysis

### Examples
```bash
# Detect AI usage in recent commits
zap detect-ai

# Analyze specific time period
zap detect-ai --since "2024-01-01"

# Focus on specific author
zap detect-ai --author "github-copilot"

# Detailed analysis
zap detect-ai --detailed
```

### Detection Methods
- Analyzes commit message patterns
- Detects AI assistant fingerprints
- Measures AI contribution percentage
- Identifies collaboration patterns

---

## ⚙️ Configuration

All commands respect the `.zap.toml` configuration file:

```toml
[zap]
ai_enabled = true
remember_patterns = true

[ollama]
host = "http://localhost:11434"
model = "deepseek-coder:33b"
timeout_ms = 30000

[ollama.models]
commit = "deepseek-coder:33b"      # For commit messages
explain = "llama3:8b"              # For code explanations
review = "deepseek-coder:33b"      # For code reviews
merge = "codellama:34b"            # For merge assistance

[style]
type_scope_required = true
imperative = true
max_subject_len = 72

[policies]
allow_cloud = false
block_secrets = true
require_tests_on = ["feat","fix","refactor"]
```

---

## 🔧 Global Options

All commands support these global options:

- `-h, --help` - Show help information
- `-V, --version` - Show version information
- `--config <FILE>` - Use specific config file
- `--verbose` - Enable verbose output
- `--quiet` - Suppress non-error output

---

## 🚨 Error Handling

Zap commands provide clear error messages and suggestions:

- **AI Unavailable**: Commands gracefully degrade when Ollama is not running
- **Git Errors**: Clear explanations of git-related issues
- **Configuration Issues**: Helpful hints for fixing config problems
- **Network Issues**: Retry logic and timeout handling

---

## 📊 Exit Codes

- `0` - Success
- `1` - General error
- `2` - Git-related error
- `3` - AI/Ollama error
- `4` - Configuration error
- `5` - Validation error

---

For more information about configuration options, see [README.md](README.md).</content>
<parameter name="filePath">/data/projects/zap/COMMANDS.md