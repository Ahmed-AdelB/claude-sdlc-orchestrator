#!/bin/bash
#===============================================================================
# setup.sh - One-command setup for Claude Code 24-hour autonomous operation
#===============================================================================
# Usage:
#   ~/.claude/autonomous/setup.sh
#
# This script:
#   1. Creates required directories
#   2. Installs systemd user service (optional)
#   3. Creates convenient aliases
#   4. Verifies the installation
#===============================================================================

set -e

AUTONOMOUS_DIR="$HOME/.claude/autonomous"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

echo -e "${BOLD}${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     CLAUDE CODE 24-HOUR AUTONOMOUS OPERATION - SETUP            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Create directories
info "Creating directories..."
mkdir -p "$AUTONOMOUS_DIR"/{tasks/queue,tasks/completed,tasks/failed,logs,sessions}
log "Directories created"

# Step 2: Make scripts executable
info "Setting permissions..."
chmod +x "$AUTONOMOUS_DIR"/*.sh 2>/dev/null || true
log "Scripts made executable"

# Step 3: Create symlinks in ~/bin
info "Creating command symlinks..."
mkdir -p "$HOME/bin"

# Remove old symlinks if they exist
rm -f "$HOME/bin/claude-24h" "$HOME/bin/claude-queue" "$HOME/bin/claude-monitor" "$HOME/bin/claude-watchdog"

# Create new symlinks
ln -sf "$AUTONOMOUS_DIR/claude-24h.sh" "$HOME/bin/claude-24h"
ln -sf "$AUTONOMOUS_DIR/task-queue.sh" "$HOME/bin/claude-queue"
ln -sf "$AUTONOMOUS_DIR/monitor.sh" "$HOME/bin/claude-monitor"
ln -sf "$AUTONOMOUS_DIR/watchdog.sh" "$HOME/bin/claude-watchdog"
log "Symlinks created in ~/bin"

# Step 4: Add to PATH if needed
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    warn "~/bin not in PATH. Add to your shell config:"
    echo "    export PATH=\"\$HOME/bin:\$PATH\""
fi

# Step 5: Install systemd service (optional)
echo ""
read -p "Install systemd user service for 24/7 operation? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p "$HOME/.config/systemd/user"
    cp "$AUTONOMOUS_DIR/claude-autonomous.service" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload
    log "Systemd service installed"

    read -p "Enable service to start on boot? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl --user enable claude-autonomous
        log "Service enabled"

        # Check if lingering is enabled
        if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
            warn "For 24/7 operation across logouts, run:"
            echo "    sudo loginctl enable-linger $USER"
        fi
    fi
fi

# Step 6: Verify installation
echo ""
info "Verifying installation..."

# Check claude
if command -v claude &>/dev/null; then
    log "Claude CLI: $(claude --version)"
else
    error "Claude CLI not found!"
fi

# Check tmux
if command -v tmux &>/dev/null; then
    log "tmux: $(tmux -V)"
else
    error "tmux not found! Install with: sudo apt install tmux"
fi

# Check scripts
for script in claude-24h task-queue monitor watchdog; do
    if [[ -x "$AUTONOMOUS_DIR/${script}.sh" ]]; then
        log "Script: ${script}.sh"
    else
        error "Missing: ${script}.sh"
    fi
done

# Step 7: Show usage
echo ""
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}SETUP COMPLETE - Quick Start Guide${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Method 1: Interactive Session (Recommended for first use)${NC}"
echo "  cd ~/projects/myapp"
echo "  claude-24h"
echo ""
echo -e "${CYAN}Method 2: Task Queue (For multiple tasks)${NC}"
echo "  claude-queue add \"Build the authentication module\""
echo "  claude-queue add \"Write tests for user registration\""
echo "  claude-queue add \"Update API documentation\""
echo "  claude-queue process ~/projects/myapp"
echo ""
echo -e "${CYAN}Method 3: With Watchdog (Auto-restart on crash)${NC}"
echo "  claude-24h ~/projects/myapp"
echo "  claude-watchdog start ~/projects/myapp"
echo ""
echo -e "${CYAN}Method 4: Docker Sandbox (Safest for autonomous operation)${NC}"
echo "  cd ~/.claude/autonomous"
echo "  docker-compose up -d"
echo "  docker-compose exec claude claude-24h /workspace"
echo ""
echo -e "${CYAN}Method 5: Systemd Service (24/7 across reboots)${NC}"
echo "  systemctl --user start claude-autonomous"
echo "  tmux attach -t claude-autonomous"
echo ""
echo -e "${CYAN}Monitoring:${NC}"
echo "  claude-monitor           # Interactive dashboard"
echo "  claude-monitor --watch   # Auto-refresh every 5s"
echo "  claude-monitor --log     # Tail latest log"
echo ""
echo -e "${BOLD}Files created in: $AUTONOMOUS_DIR${NC}"
echo ""
