#===============================================================================
# Dockerfile - Sandboxed Claude Code for 24+ hour autonomous operation
#===============================================================================
# Build:  docker build -t claude-sandbox ~/.claude/autonomous/
# Run:    docker run -it --name claude-24h -v ~/projects:/workspace claude-sandbox
#===============================================================================

FROM node:22-bookworm

# Set environment
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root
ENV CLAUDE_AUTONOMOUS_MODE=true

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    vim \
    tmux \
    screen \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    sudo \
    locales \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# Set locale
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code@latest

# Install useful global npm packages
RUN npm install -g \
    typescript \
    tsx \
    prettier \
    eslint \
    pnpm \
    yarn

# Install Python tools
RUN pip3 install --break-system-packages \
    ruff \
    black \
    mypy \
    pytest

# Create workspace directory
RUN mkdir -p /workspace /root/.claude/autonomous

# Copy configuration files
COPY settings-autonomous.json /root/.claude/autonomous/
COPY claude-24h.sh /root/.claude/autonomous/
COPY task-queue.sh /root/.claude/autonomous/
COPY monitor.sh /root/.claude/autonomous/
COPY watchdog.sh /root/.claude/autonomous/
COPY checkpoint.sh /root/.claude/autonomous/

# Make scripts executable
RUN chmod +x /root/.claude/autonomous/*.sh

# Create symlinks for easy access
RUN ln -s /root/.claude/autonomous/claude-24h.sh /usr/local/bin/claude-24h
RUN ln -s /root/.claude/autonomous/task-queue.sh /usr/local/bin/task-queue
RUN ln -s /root/.claude/autonomous/monitor.sh /usr/local/bin/claude-monitor
RUN ln -s /root/.claude/autonomous/watchdog.sh /usr/local/bin/claude-watchdog

# Set working directory
WORKDIR /workspace

# Create entrypoint script
RUN cat > /entrypoint.sh << 'EOF'
#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         CLAUDE CODE SANDBOX - 24 HOUR AUTONOMOUS MODE            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Commands available:"
echo "  claude-24h [dir] [task]    - Start 24h session"
echo "  task-queue <cmd>           - Manage task queue"
echo "  claude-monitor             - Monitor session"
echo "  claude-watchdog start      - Start auto-resume watchdog"
echo ""
echo "Workspace mounted at: /workspace"
echo ""

# Keep container running
exec "$@"
EOF
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
