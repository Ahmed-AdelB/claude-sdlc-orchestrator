# Gemini 3 Pro CLI Configuration Guide

## Overview

This guide documents how to configure Gemini CLI to use **Gemini 3 Pro** with maximum reasoning capabilities.

**Last Updated:** December 27, 2025
**Gemini CLI Version:** 0.22.3
**Account:** `ahmedalderai91@gmail.com` (Personal OAuth - Single Account)
**Machines:** GCP VM (aadel@gcp-vm) + Mac (aadel@mac)

---

## Quick Start

```bash
# GCP project variables are automatically unset in shell startup
# Just run Gemini directly:
gemini -m gemini-3-pro -y "your prompt here"

# Or use the alias:
g3p "your prompt here"
```

---

## Configuration File

**Location:** `~/.gemini/settings.json`

```json
{
  "security": {
    "auth": {
      "selectedType": "oauth-personal"
    }
  },
  "previewFeatures": true,
  "general": {
    "previewFeatures": true,
    "preferredModel": "gemini-3-pro"
  },
  "routing": {
    "preferPro": true
  },
  "thinking": {
    "level": "high"
  }
}
```

---

## Settings Explained

| Setting                      | Value            | Description                                   |
| ---------------------------- | ---------------- | --------------------------------------------- |
| `security.auth.selectedType` | `oauth-personal` | Use personal Google account (not GCP project) |
| `previewFeatures`            | `true`           | Required to access Gemini 3 models            |
| `general.preferredModel`     | `gemini-3-pro`   | Default to Gemini 3 Pro                       |
| `routing.preferPro`          | `true`           | Always use most capable model available       |
| `thinking.level`             | `high`           | Maximum reasoning depth                       |

---

## Authentication Setup

### Initial Setup (One-Time)

1. **Clear existing credentials:**

   ```bash
   rm -f ~/.gemini/oauth_creds.json ~/.gemini/google_accounts.json
   ```

2. **Run authentication:**

   ```bash
   gemini auth login
   ```

3. **Sign in with:** `ahmedalderai91@gmail.com`

4. **Copy the authorization code** from the browser and paste it in the terminal.

### Environment Variables (Auto-configured)

GCP project variables are **automatically unset** in shell startup files to prevent conflicts:

**~/.bashrc (GCP VM):**

```bash
# Gemini CLI - Personal OAuth (no project needed)
unset GOOGLE_CLOUD_PROJECT
unset GOOGLE_CLOUD_LOCATION

# Gemini aliases
alias g="gemini -y"
alias g3p="gemini -m gemini-3-pro -y"
```

**~/.zshrc (Mac):**

```bash
# Gemini CLI - Personal OAuth (no project needed)
unset GOOGLE_CLOUD_PROJECT
unset GOOGLE_CLOUD_LOCATION

# Gemini aliases
alias g="gemini -y"
alias g3p="gemini -m gemini-3-pro -y"
```

This prevents the "Permission denied on cloudaicompanion.googleapis.com" error automatically.

---

## Model Options

### Available Models

| Model            | ID                 | Best For                                   |
| ---------------- | ------------------ | ------------------------------------------ |
| Gemini 3 Pro     | `gemini-3-pro`     | Complex reasoning, architecture, debugging |
| Gemini 3 Flash   | `gemini-3-flash`   | Fast responses, simple tasks               |
| Gemini 2.5 Pro   | `gemini-2.5-pro`   | Balanced performance                       |
| Gemini 2.5 Flash | `gemini-2.5-flash` | High throughput, low latency               |

### Model Selection

```bash
# Use default model from settings
gemini -y "prompt"

# Or use the alias
g "prompt"

# Explicitly specify Gemini 3 Pro
gemini -m gemini-3-pro -y "prompt"
g3p "prompt"  # alias

# Use auto-routing (simple→Flash, complex→Pro)
gemini -m auto -y "prompt"
```

---

## Thinking Levels

Gemini 3 Pro supports thinking levels to control reasoning depth:

| Level  | Description                       | Use Case                                  |
| ------ | --------------------------------- | ----------------------------------------- |
| `LOW`  | Minimal reasoning, fast responses | Simple tasks, chat                        |
| `HIGH` | Maximum reasoning depth (default) | Complex analysis, debugging, architecture |

**Note:** As of December 2025, thinking level is NOT fully configurable per-session in Gemini CLI ([GitHub Issue #6693](https://github.com/google-gemini/gemini-cli/issues/6693)). Gemini 3 Pro uses `HIGH` by default.

---

## Usage Examples

### Basic Usage

```bash
# Simple query
gemini -y "explain async/await in Python"

# With YOLO mode (auto-approve all tools)
gemini -y "analyze the codebase and find security issues"

# Interactive mode
gemini
```

### Complex Reasoning Tasks

```bash
# Architecture review
g3p "Review the Flask app architecture in this directory and suggest improvements"

# Debugging
g3p "Debug why the tests are failing in tests/unit/"

# Code generation
g3p "Implement a rate limiter middleware for Flask"
```

### Session Management

```bash
# Resume previous session
gemini -r latest

# List available sessions
gemini --list-sessions

# Delete a session
gemini --delete-session 3
```

---

## Troubleshooting

### Error: "Permission denied on cloudaicompanion.googleapis.com"

**Cause:** GCP project environment variables are set.

**Solution:** This should be auto-fixed by shell startup. If not:

```bash
unset GOOGLE_CLOUD_PROJECT
unset GOOGLE_CLOUD_LOCATION
gemini -y "test"
```

Check that your `~/.bashrc` or `~/.zshrc` includes the `unset` commands.

### Error: "invalid_grant" during authentication

**Cause:** Authorization code expired (they expire quickly).

**Solution:** Get a fresh code by visiting the new URL immediately and pasting it quickly.

### Error: "Model not found"

**Cause:** Preview features not enabled or model name incorrect.

**Solution:**

1. Ensure `previewFeatures: true` in settings.json
2. Use exact model name: `gemini-3-pro`

### Slow First Response

**Cause:** Gemini 3 Pro with HIGH thinking level takes longer for the first token.

**This is expected.** The model is reasoning through the problem before responding.

---

## Account Configuration

**Single Account Setup (Simplified)**

| Account  | Email                      | Type          | Status |
| -------- | -------------------------- | ------------- | ------ |
| Personal | `ahmedalderai91@gmail.com` | Google AI Pro | Active |

The configuration uses a single personal OAuth account. The enterprise/ASU account was removed to simplify the setup and avoid authentication conflicts.

### Check Account Status

```bash
gemini-switch
# Shows: Gemini CLI Account: ahmedalderai91@gmail.com
#        Auth Type: oauth-personal
```

### Re-authenticate (if needed)

```bash
rm -f ~/.gemini/oauth_creds.json
gemini auth login
# Sign in with ahmedalderai91@gmail.com
```

### Credential Files

```
~/.gemini/
├── settings.json           # Configuration
├── oauth_creds.json        # Active OAuth credentials
├── google_accounts.json    # Active account info
└── accounts/
    └── ahmedalderai91_creds.json  # Backup credentials
```

---

## Rate Limits

Google AI Pro subscription includes:

- Daily request limits (varies by model)
- When limits are reached, CLI shows reset time
- Can switch to Gemini 2.5 Pro as fallback

---

## Integration with Claude Code

Use Gemini 3 Pro alongside Claude Code for multi-model workflows:

```bash
# In Claude Code, use the Skill tool
/gemini "analyze this codebase for security vulnerabilities"

# Or run directly with alias
g3p "review the changes in git diff HEAD~1"

# Full codebase analysis (1M context)
g3p "analyze the entire project structure and suggest improvements"
```

---

## References

- [Gemini 3 Developer Guide](https://ai.google.dev/gemini-api/docs/gemini-3)
- [Gemini Thinking Documentation](https://ai.google.dev/gemini-api/docs/thinking)
- [Gemini CLI Configuration](https://geminicli.com/docs/get-started/configuration/)
- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [Gemini 3 Pro Announcement](https://blog.google/products/gemini/gemini-3/)

## Dual Account Rate Limit Strategy

When running multiple Gemini agents in parallel, use both accounts to avoid rate limits:

### Available Accounts

| Profile | Email | Command |
|---------|-------|---------|
| adel | ah.adel.bakr@gmail.com | `gemini-switch adel` |
| ahmed | ahmedalderai91@gmail.com | `gemini-switch ahmed` |

### Recommended Strategy

1. **Run 2-3 agents per account** to stay under per-minute rate limits
2. **Stagger agent starts** by 5-10 seconds
3. **Switch accounts** when quota exhausted:
   ```bash
   gemini-switch ahmed  # Switch to second account
   gemini -m gemini-3-pro -y "task..."
   ```

### Example: Running 6 Agents

```bash
# Account 1 (adel) - 3 agents
gemini -m gemini-3-pro -y "Task 1" &
sleep 5 && gemini -m gemini-3-pro -y "Task 2" &
sleep 10 && gemini -m gemini-3-pro -y "Task 3" &

# Switch to Account 2 (ahmed)
gemini-switch ahmed

# Account 2 (ahmed) - 3 more agents
gemini -m gemini-3-pro -y "Task 4" &
sleep 5 && gemini -m gemini-3-pro -y "Task 5" &
sleep 10 && gemini -m gemini-3-pro -y "Task 6" &
```

### Rate Limit Error Recovery

If you see `429 Resource exhausted`:
1. Check which account is active: `gemini-switch`
2. Switch to other account: `gemini-switch ahmed` or `gemini-switch adel`
3. Continue running agents on new account
