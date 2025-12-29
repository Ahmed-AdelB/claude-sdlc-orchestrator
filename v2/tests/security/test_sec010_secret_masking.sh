#!/bin/bash
# =============================================================================
# test_sec010_secret_masking.sh - SEC-010 Secret Masking Verification Tests
# =============================================================================
# Tests for comprehensive secret masking to prevent credential leakage in logs.
# Verifies that API keys, tokens, passwords, and other secrets are properly
# redacted while preserving non-secret content.
# =============================================================================

set -euo pipefail

# =============================================================================
# TEST SETUP
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common.sh which contains mask_secrets function
source "$PROJECT_ROOT/lib/common.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

test_pass() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${RESET}: $test_name"
}

test_fail() {
    local test_name="$1"
    local reason="${2:-}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${RESET}: $test_name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
}

test_skip() {
    local test_name="$1"
    local reason="${2:-}"
    echo -e "${YELLOW}SKIP${RESET}: $test_name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
}

# Helper to check if output contains [REDACTED]
assert_masked() {
    local input="$1"
    local expected_pattern="$2"
    local test_desc="$3"

    local result
    result=$(mask_secrets "$input")

    if echo "$result" | grep -q "$expected_pattern"; then
        return 0
    else
        echo "       Input:    $input"
        echo "       Output:   $result"
        echo "       Expected: $expected_pattern"
        return 1
    fi
}

# Helper to check original secret is NOT in output
assert_secret_removed() {
    local input="$1"
    local secret="$2"
    local test_desc="$3"

    local result
    result=$(mask_secrets "$input")

    if echo "$result" | grep -q "$secret"; then
        echo "       Input:  $input"
        echo "       Output: $result"
        echo "       Secret '$secret' was NOT masked!"
        return 1
    else
        return 0
    fi
}

# =============================================================================
# TEST 1: OpenAI/Anthropic API Keys are masked
# =============================================================================

test_api_keys_masked() {
    local test_name="[1] OpenAI/Anthropic API keys are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test ANTHROPIC_API_KEY
    if ! assert_masked "ANTHROPIC_API_KEY=sk-ant-123456789abcdef" "ANTHROPIC_API_KEY=\[REDACTED\]" "ANTHROPIC_API_KEY"; then
        passed=false
    fi

    # Test OPENAI_API_KEY
    if ! assert_masked "OPENAI_API_KEY=sk-1234567890abcdefghijklmn" "OPENAI_API_KEY=\[REDACTED\]" "OPENAI_API_KEY"; then
        passed=false
    fi

    # Test sk- prefix tokens (20+ chars)
    if ! assert_secret_removed "Using key sk-abcdefghijklmnopqrst123456" "sk-abcdefghijklmnopqrst123456" "sk- token"; then
        passed=false
    fi

    # Test sk-proj- prefix tokens
    if ! assert_secret_removed "Using key sk-proj-abcdefghijklmnopqrst" "sk-proj-abcdefghijklmnopqrst" "sk-proj- token"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 2: Google API Keys are masked
# =============================================================================

test_google_keys_masked() {
    local test_name="[2] Google API keys are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test GOOGLE_API_KEY
    if ! assert_masked "GOOGLE_API_KEY=AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZabcdef" "GOOGLE_API_KEY=\[REDACTED\]" "GOOGLE_API_KEY"; then
        passed=false
    fi

    # Test GEMINI_API_KEY
    if ! assert_masked "GEMINI_API_KEY=AIzaSy123456789012345678901234567890" "GEMINI_API_KEY=\[REDACTED\]" "GEMINI_API_KEY"; then
        passed=false
    fi

    # Test AIza prefix (35 chars after)
    if ! assert_secret_removed "key=AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZabcdef" "AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZabcdef" "AIza token"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 3: GitHub tokens are masked
# =============================================================================

test_github_tokens_masked() {
    local test_name="[3] GitHub tokens are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test ghp_ (personal access token)
    if ! assert_secret_removed "GITHUB_TOKEN=ghp_abcdefghijklmnopqrstuvwxyz0123456789" "ghp_abcdefghijklmnopqrstuvwxyz0123456789" "ghp_ token"; then
        passed=false
    fi

    # Test gho_ (OAuth token)
    if ! assert_secret_removed "token=gho_abcdefghijklmnopqrstuvwxyz0123456789" "gho_abcdefghijklmnopqrstuvwxyz0123456789" "gho_ token"; then
        passed=false
    fi

    # Test ghs_ (server token)
    if ! assert_secret_removed "token=ghs_abcdefghijklmnopqrstuvwxyz0123456789" "ghs_abcdefghijklmnopqrstuvwxyz0123456789" "ghs_ token"; then
        passed=false
    fi

    # Test github_pat_ (fine-grained PAT)
    if ! assert_secret_removed "GH_PAT=github_pat_11ABCDEFGHIJKLMNOPQRST" "github_pat_11ABCDEFGHIJKLMNOPQRST" "github_pat_ token"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 4: GitLab tokens are masked
# =============================================================================

test_gitlab_tokens_masked() {
    local test_name="[4] GitLab tokens are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test glpat- (GitLab personal access token)
    if ! assert_secret_removed "GITLAB_TOKEN=glpat-abcdefghijklmnopqrst" "glpat-abcdefghijklmnopqrst" "glpat- token"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 5: AWS credentials are masked
# =============================================================================

test_aws_credentials_masked() {
    local test_name="[5] AWS credentials are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test AWS_ACCESS_KEY_ID
    if ! assert_masked "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE" "AWS_ACCESS_KEY_ID=\[REDACTED\]" "AWS_ACCESS_KEY_ID"; then
        passed=false
    fi

    # Test AWS_SECRET_ACCESS_KEY
    if ! assert_masked "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" "AWS_SECRET_ACCESS_KEY=\[REDACTED\]" "AWS_SECRET_ACCESS_KEY"; then
        passed=false
    fi

    # Test AKIA prefix
    if ! assert_secret_removed "key=AKIAIOSFODNN7EXAMPLE" "AKIAIOSFODNN7EXAMPLE" "AKIA prefix"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 6: Azure credentials are masked
# =============================================================================

test_azure_credentials_masked() {
    local test_name="[6] Azure credentials are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test AZURE_*KEY patterns
    if ! assert_masked "AZURE_STORAGE_KEY=abcdefghij123456789" "AZURE_STORAGE_KEY=\[REDACTED\]" "AZURE_STORAGE_KEY"; then
        passed=false
    fi

    # Test Azure connection string
    if ! assert_secret_removed "DefaultEndpointsProtocol=https;AccountName=myaccount;AccountKey=abc123+def456==" "AccountKey=abc123" "Azure connection"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 7: Generic password/secret/token patterns are masked
# =============================================================================

test_generic_secrets_masked() {
    local test_name="[7] Generic password/secret/token patterns are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test password= (case insensitive)
    if ! assert_masked "password=mysecretpass123" "password=\[REDACTED\]" "password="; then
        passed=false
    fi

    # Test PASSWORD= (uppercase)
    if ! assert_masked "PASSWORD=MYSECRETPASS123" "PASSWORD=\[REDACTED\]" "PASSWORD="; then
        passed=false
    fi

    # Test secret=
    if ! assert_masked "secret=top_secret_value" "secret=\[REDACTED\]" "secret="; then
        passed=false
    fi

    # Test token=
    if ! assert_masked "token=abc123xyz789" "token=\[REDACTED\]" "token="; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 8: Bearer tokens are masked
# =============================================================================

test_bearer_tokens_masked() {
    local test_name="[8] Bearer tokens are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test Bearer token
    if ! assert_secret_removed "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" "Bearer token"; then
        passed=false
    fi

    # Test bearer (lowercase)
    if ! assert_secret_removed "bearer abc123def456ghi789" "abc123def456ghi789" "bearer lowercase"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 9: Authorization headers are masked
# =============================================================================

test_authorization_headers_masked() {
    local test_name="[9] Authorization headers are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test Authorization: header
    if ! assert_masked "Authorization: Bearer abc123xyz" "Authorization:\s*\[REDACTED\]" "Authorization header"; then
        passed=false
    fi

    # Test X-Api-Key: header
    if ! assert_masked "X-Api-Key: secretkey12345" "X-Api-Key:\s*\[REDACTED\]" "X-Api-Key header"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 10: JWT tokens are masked
# =============================================================================

test_jwt_tokens_masked() {
    local test_name="[10] JWT tokens are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test full JWT (header.payload.signature)
    local jwt="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.Rq8IjqbeYjxedo"
    if ! assert_secret_removed "Token: $jwt" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" "JWT token"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 11: JSON object secrets are masked
# =============================================================================

test_json_secrets_masked() {
    local test_name="[11] JSON object secrets are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test "password": "value"
    if ! assert_masked '{"password": "secret123"}' '"password": "\[REDACTED\]"' "JSON password"; then
        passed=false
    fi

    # Test "token": "value"
    if ! assert_masked '{"token": "abc123xyz"}' '"token": "\[REDACTED\]"' "JSON token"; then
        passed=false
    fi

    # Test "secret": "value"
    if ! assert_masked '{"secret": "topsecret"}' '"secret": "\[REDACTED\]"' "JSON secret"; then
        passed=false
    fi

    # Test "api_key": "value"
    if ! assert_masked '{"api_key": "key12345"}' '"api_key": "\[REDACTED\]"' "JSON api_key"; then
        passed=false
    fi

    # Test "apiKey": "value" (camelCase)
    if ! assert_masked '{"apiKey": "key12345"}' '"apiKey": "\[REDACTED\]"' "JSON apiKey"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 12: Database connection strings are masked
# =============================================================================

test_database_connections_masked() {
    local test_name="[12] Database connection strings are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test postgres://
    if ! assert_secret_removed "postgres://user:password123@localhost:5432/db" "password123" "postgres connection"; then
        passed=false
    fi

    # Test mysql://
    if ! assert_secret_removed "mysql://admin:secret@mysql.example.com/mydb" "secret" "mysql connection"; then
        passed=false
    fi

    # Test mongodb://
    if ! assert_secret_removed "mongodb://user:pass@mongo.example.com/db" "pass" "mongodb connection"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 13: Third-party service tokens are masked (Slack, Stripe, etc.)
# =============================================================================

test_third_party_tokens_masked() {
    local test_name="[13] Third-party service tokens are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test Slack token (xoxb-)
    if ! assert_secret_removed "SLACK_TOKEN=xoxb-1234567890-abcdefghij" "xoxb-1234567890-abcdefghij" "Slack token"; then
        passed=false
    fi

    # Test Stripe live key (using placeholder pattern to avoid secret scanners)
    local stripe_prefix="sk_live_"
    local stripe_suffix="0000000000000000000000000"
    local stripe_test="${stripe_prefix}${stripe_suffix}"
    if ! assert_secret_removed "STRIPE_KEY=${stripe_test}" "${stripe_test}" "Stripe key"; then
        passed=false
    fi

    # Test SendGrid key
    if ! assert_secret_removed "SENDGRID_KEY=SG.abcdefghij.klmnopqrstuvwxyz" "SG.abcdefghij.klmnopqrstuvwxyz" "SendGrid key"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 14: Private key headers are masked
# =============================================================================

test_private_keys_masked() {
    local test_name="[14] Private key headers are masked"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test RSA private key header
    if ! assert_secret_removed "-----BEGIN RSA PRIVATE KEY-----" "BEGIN RSA PRIVATE KEY" "RSA private key"; then
        passed=false
    fi

    # Test generic private key header
    if ! assert_secret_removed "-----BEGIN PRIVATE KEY-----" "BEGIN PRIVATE KEY" "Generic private key"; then
        passed=false
    fi

    # Test PGP private key header
    if ! assert_secret_removed "-----BEGIN PGP PRIVATE KEY BLOCK-----" "BEGIN PGP PRIVATE KEY" "PGP private key"; then
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 15: Non-secret content is preserved
# =============================================================================

test_nonsecret_preserved() {
    local test_name="[15] Non-secret content is preserved"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Test normal text
    local normal_text="This is a normal log message with no secrets"
    local result
    result=$(mask_secrets "$normal_text")
    if [[ "$result" != "$normal_text" ]]; then
        echo "       Normal text was modified!"
        echo "       Input:  $normal_text"
        echo "       Output: $result"
        passed=false
    fi

    # Test code snippets
    local code="function getUserById(id) { return users.find(u => u.id === id); }"
    result=$(mask_secrets "$code")
    if [[ "$result" != "$code" ]]; then
        echo "       Code was modified!"
        echo "       Input:  $code"
        echo "       Output: $result"
        passed=false
    fi

    # Test URLs without credentials
    local url="https://api.example.com/v1/users?page=1&limit=10"
    result=$(mask_secrets "$url")
    if [[ "$result" != "$url" ]]; then
        echo "       URL was modified!"
        echo "       Input:  $url"
        echo "       Output: $result"
        passed=false
    fi

    # Test JSON without secrets
    local json='{"name": "test", "value": 123, "enabled": true}'
    result=$(mask_secrets "$json")
    if [[ "$result" != "$json" ]]; then
        echo "       JSON was modified!"
        echo "       Input:  $json"
        echo "       Output: $result"
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 16: Config file has comprehensive mask patterns
# =============================================================================

test_config_has_patterns() {
    local test_name="[16] Config file has comprehensive mask patterns"
    TESTS_RUN=$((TESTS_RUN + 1))

    local config_file="$PROJECT_ROOT/config/tri-agent.yaml"

    if [[ ! -f "$config_file" ]]; then
        test_fail "$test_name" "Config file not found: $config_file"
        return
    fi

    local passed=true
    local patterns=(
        "ANTHROPIC_API_KEY"
        "OPENAI_API_KEY"
        "GOOGLE_API_KEY"
        "ghp_"
        "gho_"
        "glpat-"
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
        "AZURE_"
        "Bearer"
        "uthorization"
        "password"
        "secret"
        "token"
    )

    for pattern in "${patterns[@]}"; do
        if ! grep -qi "$pattern" "$config_file"; then
            echo "       Missing pattern: $pattern"
            passed=false
        fi
    done

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Some patterns missing from config"
    fi
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

echo ""
echo "============================================================================="
echo " SEC-010: Secret Masking Verification Tests"
echo "============================================================================="
echo ""

# Run all tests
test_api_keys_masked
test_google_keys_masked
test_github_tokens_masked
test_gitlab_tokens_masked
test_aws_credentials_masked
test_azure_credentials_masked
test_generic_secrets_masked
test_bearer_tokens_masked
test_authorization_headers_masked
test_jwt_tokens_masked
test_json_secrets_masked
test_database_connections_masked
test_third_party_tokens_masked
test_private_keys_masked
test_nonsecret_preserved
test_config_has_patterns

# Print summary
echo ""
echo "============================================================================="
echo " Test Summary"
echo "============================================================================="
echo ""
echo "  Tests run:    $TESTS_RUN"
echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${RESET}"
echo -e "  Tests failed: ${RED}$TESTS_FAILED${RESET}"
echo ""

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}ALL SEC-010 TESTS PASSED${RESET}"
    exit 0
else
    echo -e "${RED}SOME TESTS FAILED${RESET}"
    exit 1
fi
