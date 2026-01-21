# Gemini CLI Configuration Changes - December 26, 2025

## Session Summary

This document captures the configuration changes made to set up a 2-account Gemini CLI authentication system with `ahmedalderai91@gmail.com` as the default account.

---

## Problem Statement

1. Needed to update CLAUDE.md to use `gemini-3-pro` instead of `gemini-3-pro-preview`
2. Required re-enabling `GOOGLE_CLOUD_PROJECT` for ASU enterprise account
3. Wanted to set up multi-account switching for quota management
4. Needed to restore OAuth credentials from backups

---

## Investigation: Yesterday vs Today

### Files Modified Today (Dec 26, 2025)

| File                         | Last Modified | Changes                      |
| ---------------------------- | ------------- | ---------------------------- |
| `~/.gemini/settings.json`    | 21:15         | Model name, routing settings |
| `~/.codex/config.toml`       | 17:43         | Added profiles               |
| `~/.gemini/gemini-switch.sh` | 21:20         | Account switcher script      |
| `~/.gemini/accounts/`        | 21:21         | Multi-account credentials    |

### Previous Configuration (Before Dec 26)

```json
// ~/.gemini/settings.json (old)
{
  "security": {
    "auth": {
      "googleCloudProject": "nth-facility-468017-u4"
    }
  },
  "previewFeatures": true
}
```

- Used ASU Workspace account with `GOOGLE_CLOUD_PROJECT`
- Single account setup

---

## Changes Made

### 1. CLAUDE.md Updates

**Changed `gemini-3-pro-preview` → `gemini-3-pro` in 4 locations:**

```bash
# Locations updated:
# - Multi-Model Routing table (line 63)
# - Gemini CLI examples (lines 152, 157)
# - Gemini Configuration File example (line 180)
# - Gemini 3 Pro Setup section (line 204)
```

**Updated Account Switching section** from 2 accounts to 3 accounts with:

- Default account indicator
- Account types table
- Enterprise setup instructions
- Note about OAuth-only authentication

### 2. bashrc - GOOGLE_CLOUD_PROJECT (Commented by Default)

```bash
# Personal accounts don't need GOOGLE_CLOUD_PROJECT
# Only set when using ASU account (gemini-switch asu)
#export GOOGLE_CLOUD_PROJECT="nth-facility-468017-u4"
```

### 3. Gemini Account Switcher Script

**Created:** `~/.gemini/gemini-switch.sh`

```bash
#!/bin/bash
# Gemini CLI 2-Account Switcher
# Default: ahmedalderai91@gmail.com (ahmed)
# ASU: ahmed_adel_hr@cis.asu.edu.eg (requires GOOGLE_CLOUD_PROJECT)

# Features:
# - Shows current account status with color output
# - Switches between ahmed/asu accounts
# - Swaps oauth_creds.json files
# - Updates settings.json appropriately
```

**Linked to PATH:** `~/.local/bin/gemini-switch`

### 4. Account Credentials Structure

```
~/.gemini/
├── accounts/
│   ├── ahmedalderai91_creds.json    # ✅ Personal (default)
│   └── asu_creds.json               # ✅ Enterprise (ASU)
├── oauth_creds.json                  # Active credentials (swapped by gemini-switch)
├── google_accounts.json              # Active account tracker
├── settings.json                     # Gemini CLI settings
└── gemini-switch.sh                  # Switcher script
```

---

## Backup Restoration (Key Discovery)

### Problem

After clearing credentials for fresh OAuth setup, we discovered existing backups on Mac containing valid OAuth tokens.

### Backup Locations Found

```bash
# Search command used:
find ~ -maxdepth 3 -name "*gemini*" -o -name "*oauth*" 2>/dev/null

# Backups discovered:
/Users/aadel/.gemini.backup.1766742310/    # Dec 26 13:45 - Personal (ahmed)
/Users/aadel/.gemini.backup.1766776061/    # Dec 26 23:07 - ASU account
```

### Backup Contents

| Backup Folder                  | Timestamp    | Account                      |
| ------------------------------ | ------------ | ---------------------------- |
| `~/.gemini.backup.1766742310/` | Dec 26 13:45 | ahmedalderai91@gmail.com     |
| `~/.gemini.backup.1766776061/` | Dec 26 23:07 | ahmed_adel_hr@cis.asu.edu.eg |

### Verification

```bash
# Check which account each backup contains:
cat ~/.gemini.backup.1766776061/google_accounts.json
# {"active": "ahmed_adel_hr@cis.asu.edu.eg", "old": []}

cat ~/.gemini.backup.1766742310/google_accounts.json
# {"active": "ahmedalderai91@gmail.com", "old": []}
```

### Restoration Steps

```bash
# 1. Copy ASU credentials from backup
cp ~/.gemini.backup.1766776061/oauth_creds.json ~/.gemini/accounts/asu_creds.json

# 2. Copy personal credentials from backup
cp ~/.gemini.backup.1766742310/oauth_creds.json ~/.gemini/accounts/ahmedalderai91_creds.json

# 3. Verify files
ls -la ~/.gemini/accounts/
# ahmedalderai91_creds.json  (1807 bytes)
# asu_creds.json             (1812 bytes)

# 4. Copy to GCP VM
scp ~/.gemini/accounts/asu_creds.json ~/.gemini/accounts/ahmedalderai91_creds.json \
    aadel@100.104.204.74:~/.gemini/accounts/

# 5. Set default account
gemini-switch ahmed
```

---

## Service Account Attempt (Failed)

### What We Tried

1. Copied service account key from Mac:

   ```bash
   ssh aadel@100.90.171.108 "cat /Users/aadel/Downloads/nth-facility-468017-u4-259ce7b56f67.json" > ~/gcp-service-account.json
   ```

2. Service account details:
   - Email: `gemini@nth-facility-468017-u4.iam.gserviceaccount.com`
   - Project: `nth-facility-468017-u4`

3. Added IAM role from Mac:
   ```bash
   gcloud projects add-iam-policy-binding nth-facility-468017-u4 \
     --member="serviceAccount:gemini@nth-facility-468017-u4.iam.gserviceaccount.com" \
     --role="roles/cloudaicompanion.user"
   ```

### Why It Failed

**Gemini CLI does NOT support service account authentication.**

- Gemini CLI only uses OAuth flow
- Setting `GOOGLE_APPLICATION_CREDENTIALS` has no effect
- The CLI always prompts for browser-based OAuth

**Error received:**

```
Permission 'cloudaicompanion.companions.generateChat' denied on resource
'//cloudaicompanion.googleapis.com/projects/nth-facility-468017-u4/locations/global'
```

### Conclusion

Service accounts cannot be used with Gemini CLI. All accounts must use OAuth authentication via browser.

---

## Final Configuration

### ~/.gemini/settings.json (Personal - Default)

```json
{
  "security": { "auth": { "selectedType": "oauth-personal" } },
  "previewFeatures": true,
  "general": { "previewFeatures": true, "preferredModel": "gemini-3-pro" },
  "routing": { "preferPro": true },
  "thinking": { "level": "high" }
}
```

### ~/.gemini/settings.json (ASU - Enterprise)

```json
{
  "security": { "auth": { "selectedType": "oauth-personal" } },
  "googleCloudProject": "nth-facility-468017-u4",
  "previewFeatures": true,
  "general": { "previewFeatures": true, "preferredModel": "gemini-3-pro" },
  "routing": { "preferPro": true },
  "thinking": { "level": "high" }
}
```

### 2-Account Setup (Final Status)

| Profile | Email                        | Type       | Default | Status     |
| ------- | ---------------------------- | ---------- | ------- | ---------- |
| ahmed   | ahmedalderai91@gmail.com     | Personal   | ✅ Yes  | ✅ Working |
| asu     | ahmed_adel_hr@cis.asu.edu.eg | Enterprise | No      | ✅ Working |

### Usage

```bash
# Check current account
gemini-switch

# Switch to personal (default - no project needed)
gemini-switch ahmed
unset GOOGLE_CLOUD_PROJECT

# Switch to ASU (enterprise - needs project)
gemini-switch asu
export GOOGLE_CLOUD_PROJECT="nth-facility-468017-u4"

# Test account
gemini -y "respond with: OK"
```

---

## Key Learnings

1. **Gemini CLI only supports OAuth** - Service accounts don't work
2. **Enterprise accounts require GOOGLE_CLOUD_PROJECT** - Set in environment
3. **Personal accounts don't need project** - Simpler setup
4. **Model name changed** - `gemini-3-pro-preview` → `gemini-3-pro`
5. **Credentials are portable** - Can copy `oauth_creds.json` between machines
6. **Check for backups first** - `~/.gemini.backup.*` folders contain previous OAuth tokens
7. **OAuth tokens have refresh_token** - Even expired access_tokens can be refreshed

---

## Files Changed Summary

| File                                           | Action                              |
| ---------------------------------------------- | ----------------------------------- |
| `~/.claude/CLAUDE.md`                          | Updated model names, 2-account docs |
| `~/.bashrc`                                    | GOOGLE_CLOUD_PROJECT commented out  |
| `~/.gemini/settings.json`                      | Updated for personal OAuth          |
| `~/.gemini/gemini-switch.sh`                   | Created 2-account switcher          |
| `~/.gemini/accounts/ahmedalderai91_creds.json` | Restored from backup                |
| `~/.gemini/accounts/asu_creds.json`            | Restored from backup                |
| `~/.local/bin/gemini-switch`                   | Symlink to switcher script          |

---

## Troubleshooting

### "Vertex AI requires GOOGLE_CLOUD_PROJECT" Error

```bash
# For personal account - unset the variable
unset GOOGLE_CLOUD_PROJECT
gemini-switch ahmed

# For ASU account - set the variable
export GOOGLE_CLOUD_PROJECT="nth-facility-468017-u4"
gemini-switch asu
```

### Credentials Not Found

```bash
# Check backup folders on Mac
ls -la ~/.gemini.backup.*/oauth_creds.json

# Restore from backup
cp ~/.gemini.backup.TIMESTAMP/oauth_creds.json ~/.gemini/accounts/ACCOUNT_creds.json
```

### Token Expired

OAuth credentials include a `refresh_token` - Gemini CLI will automatically refresh expired access tokens. If still failing, re-authenticate:

```bash
rm ~/.gemini/oauth_creds.json
gemini "test"  # Will prompt for browser OAuth
cp ~/.gemini/oauth_creds.json ~/.gemini/accounts/ACCOUNT_creds.json
```

---

---

## Final Simplification (December 27, 2025)

### Decision: Single Account Setup

After experimenting with a 2-account setup, the configuration was simplified to use only the personal account:

**Reason:** The enterprise/ASU account required `GOOGLE_CLOUD_PROJECT` which conflicted with personal OAuth authentication, causing recurring permission errors.

### Changes Made

1. **Removed ASU/Enterprise Account:**
   - Deleted `~/.gemini/accounts/asu_creds.json`
   - Removed ASU-related documentation from CLAUDE.md

2. **Auto-unset GCP Variables:**
   Added to shell startup files (`~/.bashrc` on GCP, `~/.zshrc` on Mac):

   ```bash
   # Gemini CLI - Personal OAuth (no project needed)
   unset GOOGLE_CLOUD_PROJECT
   unset GOOGLE_CLOUD_LOCATION

   # Gemini aliases
   alias g="gemini -y"
   alias g3p="gemini -m gemini-3-pro -y"
   ```

3. **Updated Model Name:**
   - Changed `gemini-3-pro-preview` → `gemini-3-pro` everywhere

4. **Simplified gemini-switch.sh:**
   Now only shows account status, no switching functionality needed.

### Final Configuration

**~/.gemini/settings.json:**

```json
{
  "security": { "auth": { "selectedType": "oauth-personal" } },
  "previewFeatures": true,
  "general": { "previewFeatures": true, "preferredModel": "gemini-3-pro" },
  "routing": { "preferPro": true },
  "thinking": { "level": "high" }
}
```

**Account:** `ahmedalderai91@gmail.com` (Personal OAuth - Single Account)

**Machines Configured:**
| Machine | Shell | Tailscale IP |
|---------|-------|--------------|
| GCP VM | bash | 100.104.204.74 |
| Mac | zsh | 100.90.171.108 |

### Verification

Both machines tested and working:

```bash
# GCP
gemini -y "respond: GCP OK"  # ✅ Working

# Mac
gemini -y "respond: MAC OK"  # ✅ Working
```

### Files Removed

| File                                | Reason                     |
| ----------------------------------- | -------------------------- |
| `~/.gemini/accounts/asu_creds.json` | Enterprise account removed |
| `~/setup-gemini-accounts.sh`        | No longer needed           |

---

_Document generated: December 26, 2025_
_Updated: December 27, 2025 (single account simplification)_
_Session: Claude Code (Opus 4.5)_
