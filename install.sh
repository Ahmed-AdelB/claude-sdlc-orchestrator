#!/bin/bash
# Claude Code SDLC Orchestrator - Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/Ahmed-AdelB/claude-sdlc-orchestrator/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPO="Ahmed-AdelB/claude-sdlc-orchestrator"
CLAUDE_DIR="$HOME/.claude"
# SECURITY: Use mktemp for secure temporary directory (prevents race conditions)
TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'claude-sdlc-orchestrator')

# Ensure temp dir was created successfully
if [ ! -d "$TEMP_DIR" ]; then
    log_error "Failed to create secure temporary directory"
    exit 1
fi

# Set restrictive permissions on temp dir
chmod 700 "$TEMP_DIR"

# Cleanup trap - ensure temp dir is removed on exit
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${CYAN}$1${NC}"; }

# Banner
echo ""
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_header "  Claude Code SDLC Orchestrator - Installer"
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check dependencies
log_info "Checking dependencies..."

if ! command -v git &> /dev/null; then
    log_error "git is not installed. Please install git first."
    exit 1
fi

if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    log_error "Neither curl nor wget is installed. Please install one of them."
    exit 1
fi

log_success "Dependencies satisfied"

# Backup existing config
if [ -d "$CLAUDE_DIR" ]; then
    BACKUP_DIR="${CLAUDE_DIR}.backup.$(date +%Y%m%d_%H%M%S)"

    # SECURITY: Check if backup destination is a symlink (prevent symlink attacks)
    if [ -L "$BACKUP_DIR" ]; then
        log_error "Backup destination is a symlink - possible security attack. Aborting."
        exit 1
    fi

    log_info "Backing up existing configuration to $BACKUP_DIR..."
    cp -r "$CLAUDE_DIR" "$BACKUP_DIR"
    # Set restrictive permissions on backup
    chmod -R 700 "$BACKUP_DIR"
    log_success "Backup created"
fi

# Change to temp directory (mktemp already created it)
log_info "Changing to temporary directory..."
if ! cd "$TEMP_DIR"; then
    log_error "Failed to change to temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clone repository
log_info "Cloning repository from GitHub..."
if git clone --depth 1 "https://github.com/$REPO.git" . 2>/dev/null; then
    log_success "Repository cloned"
else
    log_error "Failed to clone repository"
    exit 1
fi

# Create .claude directory if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Copy configuration files
log_info "Installing configuration files..."

# Copy main config files
for file in CLAUDE.md settings.json .mcp.json README.md; do
    if [ -f ".claude/$file" ]; then
        cp ".claude/$file" "$CLAUDE_DIR/"
        log_success "Installed $file"
    fi
done

# Copy agents directory
if [ -d ".claude/agents" ]; then
    mkdir -p "$CLAUDE_DIR/agents"
    cp -r .claude/agents/* "$CLAUDE_DIR/agents/"
    AGENT_COUNT=$(find "$CLAUDE_DIR/agents" -name "*.md" | wc -l)
    log_success "Installed $AGENT_COUNT agents"
fi

# Copy commands directory
if [ -d ".claude/commands" ]; then
    mkdir -p "$CLAUDE_DIR/commands"
    cp -r .claude/commands/* "$CLAUDE_DIR/commands/"
    COMMAND_COUNT=$(find "$CLAUDE_DIR/commands" -name "*.md" | wc -l)
    log_success "Installed $COMMAND_COUNT slash commands"
fi

# Copy hooks directory
if [ -d ".claude/hooks" ]; then
    mkdir -p "$CLAUDE_DIR/hooks"
    cp -r .claude/hooks/* "$CLAUDE_DIR/hooks/"
    chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null || true
    HOOK_COUNT=$(find "$CLAUDE_DIR/hooks" -name "*.sh" | wc -l)
    log_success "Installed $HOOK_COUNT hooks"
fi

# Copy plans directory if exists
if [ -d ".claude/plans" ]; then
    mkdir -p "$CLAUDE_DIR/plans"
    cp -r .claude/plans/* "$CLAUDE_DIR/plans/" 2>/dev/null || true
fi

# Copy scripts directory if exists
if [ -d ".claude/scripts" ]; then
    mkdir -p "$CLAUDE_DIR/scripts"
    cp -r .claude/scripts/* "$CLAUDE_DIR/scripts/"
    chmod +x "$CLAUDE_DIR/scripts/"*.sh 2>/dev/null || true
fi

# Cleanup (handled by trap, but explicit for clarity)
log_info "Cleaning up..."
cd /
# Note: TEMP_DIR cleanup is handled by EXIT trap for safety
log_success "Cleanup complete"

# Verify installation
log_info "Verifying installation..."

ERRORS=0

if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    log_warning "CLAUDE.md not found"
    ((ERRORS++))
fi

if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    log_warning "settings.json not found"
    ((ERRORS++))
fi

if [ ! -d "$CLAUDE_DIR/agents" ]; then
    log_warning "agents directory not found"
    ((ERRORS++))
fi

if [ ! -d "$CLAUDE_DIR/commands" ]; then
    log_warning "commands directory not found"
    ((ERRORS++))
fi

if [ ! -d "$CLAUDE_DIR/hooks" ]; then
    log_warning "hooks directory not found"
    ((ERRORS++))
fi

# Summary
echo ""
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_header "  Installation Summary"
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "  Installation directory: $CLAUDE_DIR"
echo ""

# Count installed items
TOTAL_AGENTS=$(find "$CLAUDE_DIR/agents" -name "*.md" 2>/dev/null | wc -l)
TOTAL_COMMANDS=$(find "$CLAUDE_DIR/commands" -name "*.md" 2>/dev/null | wc -l)
TOTAL_HOOKS=$(find "$CLAUDE_DIR/hooks" -name "*.sh" 2>/dev/null | wc -l)

echo "  Agents:   $TOTAL_AGENTS"
echo "  Commands: $TOTAL_COMMANDS"
echo "  Hooks:    $TOTAL_HOOKS"
echo ""

if [ $ERRORS -eq 0 ]; then
    log_success "Installation completed successfully!"
else
    log_warning "Installation completed with $ERRORS warnings"
fi

echo ""
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_header "  Next Steps"
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Restart Claude Code to load the new configuration"
echo "  2. Try a slash command: /sdlc:brainstorm [feature]"
echo "  3. Configure hooks: export CLAUDE_HOOK_MODE=ask"
echo ""
echo "  For tri-agent reviews (requires Codex + Gemini CLI):"
echo "  - Install Codex CLI: npm install -g @openai/codex-cli"
echo "  - Install Gemini CLI: pip install google-generativeai-cli"
echo "  - Enable: export TRI_AGENT_REVIEW=true"
echo ""
echo "  Documentation: $CLAUDE_DIR/README.md"
echo "  GitHub: https://github.com/$REPO"
echo ""

exit 0
