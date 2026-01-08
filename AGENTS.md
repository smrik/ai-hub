# Global AGENTS.md

This file provides universal guidance to all AI coding agents (Claude Code, Gemini CLI, Codex CLI) across all projects.

**Standard:** [AGENTS.md Open Standard](https://ainativedev.io/news/the-rise-of-agents-md-an-open-standard-and-single-source-of-truth-for-ai-coding-agents)

## Session Continuity

**At the start of each session**, check for `.agent/session-state.md` in the project root.
If present, read it to understand:
- What the previous agent was working on
- Recent changes made
- Known blockers or issues

**Before ending a session** (or when user says "handoff", "switch agent", or exits), **you MUST update `.agent/session-state.md`** with the following format:

```markdown
# Session State

**Updated:** [timestamp]
**Agent:** [Your CLI name: Claude Code / Gemini CLI / Codex CLI]
**Project:** [Current working directory]

## Current Task
[Brief description of the main task/goal]

## Recent Actions
- [Action 1]
- [Action 2]
- [Action 3]

## Next Steps
- [Next step 1]
- [Next step 2]

## Known Issues
- [Any blockers or issues encountered]

## Notes
[Any additional context the next agent should know]
```

**IMPORTANT:** This handoff is critical for multi-agent workflows. The user switches between Claude, Gemini, and Codex based on rate limits and task type. Each agent should:
1. Read session-state.md at session start (if it exists)
2. Offer to write session-state.md when the user ends the session or says "handoff"
3. Keep the summary concise (avoid filling context window)

This enables seamless handoffs between Claude Code, Gemini CLI, and Codex CLI.

## Cross-CLI Configuration

**Active CLIs:**
- Claude Code (`.claude/`) - Anthropic Claude Sonnet 4.5
- Gemini CLI (`.gemini/`) - Google Gemini 2.0 Flash Thinking
- Codex CLI (`.codex/`) - OpenAI GPT-5.2 Codex

**MCP Servers (Shared):**
- Perplexity - Research and web search
- BrightData - Web scraping
- Context7 - Context management
- Excel MCP - Spreadsheet operations
- MCP Gateway - Multi-model routing
- Obsidian Automation - Obsidian plugin testing

**Sync Command:** Run `sync-agents` to synchronize configs across all CLIs.

## Universal Development Patterns

### Code Quality Standards

- **TypeScript:** Strict mode, no `any` types
- **Testing:** Jest for unit tests, integration tests where applicable
- **Error Handling:** Try-catch with context logging
- **Documentation:** JSDoc for public APIs
- **Formatting:** Prettier with 2-space indentation

### Git Workflow

```bash
# Always check status before committing
git status

# Stage specific files (not git add .)
git add <specific-files>

# Descriptive commit messages
git commit -m "feat: add X feature" -m "Co-Authored-By: <CLI-Name>"

# Push requires confirmation (see permissions)
git push
```

### Permissions Philosophy

**Auto-Approve (allow):**
- Read any file
- Write code files (ts, js, py, etc.)
- Basic git operations (status, diff, log, add, commit)
- Package managers (npm, pip, cargo)
- Build tools (make, jest, eslint, tsc)
- File utilities (ls, grep, find, cat)

**Ask First:**
- git push, merge, rebase
- Deleting files (rm, rmdir)
- Network operations (curl, wget)
- Sensitive config files (package.json, .env)
- Database operations

**Deny:**
- sudo/su commands
- Disk operations (dd, mkfs, fdisk)
- Reading secrets (.env, SSH keys, AWS credentials)

### MCP Server Best Practices

- Always check if MCP server is available before using
- Handle MCP server failures gracefully
- Cache MCP responses when appropriate
- Use Perplexity for research, not for code generation

## Rate Limit Fallback Strategy

When Claude Code hits rate limits:

1. **Switch to Codex CLI** - Higher limits, GPT-5.2-codex
   ```bash
   codex chat
   ```

2. **Switch to Gemini CLI** - Unlimited (with API key)
   ```bash
   gemini chat
   ```

3. **Use MCP Gateway** - Route through alternative models
   ```bash
   # Claude can call Codex via MCP
   claude mcp call codex <prompt>
   ```

## Project-Specific Instructions

Each project may have its own `AGENTS.md` file. Project-level instructions take precedence over global instructions.

**Lookup Order:**
1. `<project-root>/AGENTS.md` - Project-specific
2. `<project-root>/.agent/session-state.md` - Session context
3. `~/.agent-sync/AGENTS.md` - This file (global defaults)

## Common Tasks

### Starting a New Project

```bash
# Initialize with AGENTS.md
mkdir new-project && cd new-project
git init
cp ~/.agent-sync/AGENTS.md ./AGENTS.md
mkdir .agent
# Customize project-specific instructions
```

### Switching Between CLIs

```bash
# Sync configs before switching
sync-agents

# Optional: Record handoff context
sync-agents --handoff "Working on X, next step is Y"

# Then start new CLI
codex chat  # or gemini chat
```

### Debugging Across CLIs

- Claude: `.claude/history.jsonl`, `.claude/debug/`
- Gemini: `.gemini/history/`, `.gemini/tmp/`
- Codex: `.codex/log/`, `.codex/sessions/`

## CLI-Specific Notes

### Claude Code
- Best for: Complex refactoring, architectural decisions
- Rate Limits: ~500 messages/day (Sonnet 4.5)
- Context: 200K tokens
- Strengths: Deep reasoning, safe code modifications

### Gemini CLI
- Best for: Rapid prototyping, multimodal tasks
- Rate Limits: Based on API tier (can be unlimited)
- Context: 2M tokens (Gemini 2.0 Flash)
- Strengths: Fast responses, large context window

### Codex CLI
- Best for: Large-scale code generation, batch operations
- Rate Limits: Higher than Claude
- Context: 128K tokens (GPT-5.2-codex)
- Strengths: Code completion, OpenAI ecosystem integration

## Security Guidelines

**Never commit:**
- `.env` files
- API keys in code
- SSH private keys
- Database credentials
- OAuth tokens

**Always:**
- Use environment variables for secrets
- Add sensitive files to `.gitignore`
- Review diffs before committing
- Use `.env.example` templates

## Preferences

**User Preferences:**
- Prefer TypeScript over JavaScript
- Use functional programming patterns when appropriate
- Verbose logging for debugging
- ADHD-friendly UI (clear visual feedback, progress indicators)
- Queue-based workflows over timer-based
- Zeigarnik Effect for engagement (strategic interruptions)

**Communication Style:**
- Be concise but thorough
- Provide examples for complex concepts
- Explain trade-offs when multiple approaches exist
- Ask clarifying questions before large changes

---

**Last Updated:** 2026-01-08
**Maintained By:** User + AI Coding Agents (Collaborative)
**Sync Source:** `~/.agent-sync/AGENTS.md`
