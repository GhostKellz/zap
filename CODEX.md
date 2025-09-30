# Zap Ollama Integration - Knowledge Transfer

## Project Overview
This document outlines the work completed on integrating Ollama (local LLM) for AI-powered commit message generation in the Zap Git workflow tool.

## Completed Work

### ✅ Configuration Integration
- **File**: `.zap.toml`
- **Changes**: Added Ollama configuration section with:
  - `host`: Ollama server URL (default: "http://localhost:11434")
  - `model`: AI model to use (default: "deepseek-coder:33b")
  - `timeout_ms`: Request timeout (default: 30000ms)

### ✅ Ollama Client Implementation
- **File**: `src/ollama.zig`
- **Features**:
  - `OllamaClient` struct with configuration and HTTP communication
  - `ping()`: Check if Ollama server is available
  - `listModels()`: Get available models from Ollama
  - `generateCommitMessage()`: Generate AI commit messages from git diffs
  - `generate()`: Low-level text generation using Ollama API

### ✅ Commit Command Integration
- **File**: `src/main.zig`
- **Changes**:
  - Updated `handleCommit()` function to use Ollama for AI commit message generation
  - Added configuration loading for Ollama settings
  - Integrated AI availability checking before generation
  - Added proper error handling for Ollama unavailability

### ✅ Build System Resolution
- **Files**: `build.zig`, `build.zig.zon`
- **Issue**: zsync module dependency conflicts when using zhttp library
- **Solution**: Removed zhttp dependency entirely, implemented HTTP communication using curl subprocess
- **Result**: Clean build without dependency conflicts

## Current State

### ✅ Build Status
- Project compiles successfully with `zig build`
- No dependency conflicts
- All modules properly imported

### ✅ Basic Functionality
- Ollama client initializes correctly
- Ping functionality works (can detect if Ollama is running)
- Configuration loading works
- Git diff extraction works

### ❌ Blocking Issue: JSON Parsing Error

**Error**: `error.MissingField` during commit message generation
**Debug Output**: `{"error":"invalid character 'h' after object key:value pair"}`

**Root Cause Analysis**:
The Ollama API is returning an error response instead of the expected generation response. The error message suggests malformed JSON is being sent to Ollama.

**Suspected Issues**:

1. **JSON Payload Malformation**: The JSON payload sent to Ollama's `/api/generate` endpoint may have syntax errors
2. **String Escaping**: The prompt text may contain characters that break JSON parsing
3. **API Compatibility**: The request format may not match Ollama's expected API

**Current Implementation Details**:

```zig
// JSON payload construction in generate() method
const json_payload = try std.fmt.allocPrint(self.allocator,
    \\{{"model":"{s}","prompt":"{s}","stream":false,"options":{{"temperature":{d},"num_predict":{d}}}}}
, .{
    request.model,      // No escaping applied
    request.prompt,     // No escaping applied - POTENTIAL ISSUE
    options.temperature orelse 0.7,
    options.num_predict orelse 128,
});
```

## Next Steps for Maintainer

### Immediate Priority: Fix JSON Parsing Error

1. **Debug the JSON Payload**:
   - Add logging to print the exact JSON being sent to Ollama
   - Verify JSON syntax with a JSON validator
   - Check for special characters in git diff output that might break JSON

2. **Implement Proper String Escaping**:
   - Use Zig's JSON stringification instead of manual formatting
   - Or implement proper JSON escaping for the prompt field

3. **Test API Compatibility**:
   - Verify the request format matches Ollama's API documentation
   - Test with simple prompts first to isolate the issue

4. **Handle Error Responses**:
   - Parse Ollama error responses properly
   - Display meaningful error messages to users

### Potential Solutions

**Option A: Fix Manual JSON Construction**
```zig
// Use proper JSON serialization
const payload = .{
    .model = request.model,
    .prompt = request.prompt,
    .stream = false,
    .options = options,
};
const json_payload = try std.json.stringifyAlloc(self.allocator, payload, .{});
```

**Option B: Add Request Logging**
```zig
std.debug.print("Sending to Ollama: {s}\n", .{json_payload});
// Then test with curl manually:
// curl -X POST http://localhost:11434/api/generate -H "Content-Type: application/json" -d '<logged_payload>'
```

### Testing Strategy

1. **Unit Test Ollama Client**:
   - Test with simple prompts first
   - Verify JSON parsing works with valid responses
   - Test error handling

2. **Integration Testing**:
   - Test with actual git diffs
   - Verify end-to-end commit message generation
   - Test error scenarios (Ollama offline, invalid models, etc.)

### Configuration Notes

- Ollama should be running on `localhost:11434`
- Model `deepseek-coder:33b` is recommended for code-related tasks
- Configuration is loaded from `.zap.toml` in the project root

### Dependencies

- **Required**: curl (for HTTP communication)
- **Optional**: Docker (for running Ollama)
- **Zig Version**: 0.16.0-dev (as used in build)

### File Structure

```
src/
├── main.zig          # CLI entry point, commit command handler
├── ollama.zig        # Ollama client implementation
├── root.zig          # Module exports
└── ...               # Other existing files

.zap.toml             # Configuration file
build.zig             # Build configuration
build.zig.zon         # Dependencies
```

## Quick Start for New Maintainer

1. **Setup Environment**:
   ```bash
   # Ensure Ollama is running
   docker start ollama  # or ollama serve

   # Build the project
   zig build
   ```

2. **Test Current State**:
   ```bash
   # Should show AI enabled
   ./zig-out/bin/zap --help

   # Test commit with staged changes
   git add .
   ./zig-out/bin/zap commit
   ```

3. **Debug the Issue**:
   - The error occurs in `ollama.zig:generate()`
   - Add debug prints to see the JSON payload
   - Test Ollama API manually with curl

## Contact Information

This work was completed as part of integrating local AI capabilities into the Zap Git workflow tool. The Ollama integration provides a privacy-focused alternative to cloud-based AI services for commit message generation.

---

*Knowledge transfer completed: September 29, 2025*</content>
<parameter name="filePath">/data/projects/zap/CODEX.md