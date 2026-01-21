# Gemini Dual Account Configuration

**Status:** Active
**Config File:** `~/.gemini/google_accounts.json`

## Overview
The system supports switching between two Google accounts for Gemini API access to manage rate limits and separate concerns.

## Accounts
1. **Primary:** `ah.adel.bakr@gmail.com`
   - Role: Main development, higher tier quota.
2. **Secondary:** `ahmedalderai91@gmail.com`
   - Role: Fallback, testing, separate quota bucket.

## Switching Tool: `gemini-switch.sh`
Located at `~/.gemini/gemini-switch.sh`.

### Usage
- **List Accounts:** `gemini-switch list`
- **Switch to Account:** `gemini-switch <email>` or `gemini-switch <index>`
- **Add New:** `gemini-switch add` (Triggers OAuth flow)

### Mechanism
The script swaps the `oauth_creds.json` file in `~/.gemini/` with the stored credential file for the selected account (e.g., `ah_adel_bakr_gmail_com_creds.json`) and updates `google_accounts.json`.

## Configuration Files
- `~/.gemini/google_accounts.json`: Tracks active account and available list.
- `~/.gemini/oauth_creds.json`: Current active credentials.
- `~/.gemini/accounts/`: Storage for credential files of all accounts.
