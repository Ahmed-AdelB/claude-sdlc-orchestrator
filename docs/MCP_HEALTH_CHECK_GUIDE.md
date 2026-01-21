# MCP Server Health Check System

> **Version:** 1.0.0 | **Author:** Ahmed Adel Bakr Alderai | **Updated:** 2026-01-21

## Overview

Comprehensive health monitoring system for all 13 MCP (Model Context Protocol) servers configured in `~/.claude/mcp.json`. The system provides:

- Individual health checks for each MCP server
- Aggregate health status reporting
- Auto-recovery capabilities for failed servers
- Prometheus-compatible metrics export
- Integration with the existing tri-agent monitoring infrastructure

## MCP Servers Monitored (13)

| Server              | Runner | Package                                                     | Dependencies             |
| ------------------- | ------ | ----------------------------------------------------------- | ------------------------ |
| git                 | uvx    | mcp-server-git@2025.4.8                                     | -                        |
| github              | npx    | @modelcontextprotocol/server-github@2025.4.8                | GITHUB_TOKEN             |
| filesystem          | npx    | @modelcontextprotocol/server-filesystem@2025.12.18          | -                        |
| memory              | npx    | @modelcontextprotocol/server-memory@2025.11.25              | -                        |
| fetch               | npx    | @modelcontextprotocol/server-fetch@2025.4.8                 | -                        |
| sequential-thinking | npx    | @modelcontextprotocol/server-sequential-thinking@2025.12.18 | -                        |
| puppeteer           | npx    | @modelcontextprotocol/server-puppeteer@2025.5.12            | -                        |
| playwright          | npx    | @playwright/mcp@0.0.54                                      | -                        |
| postgres            | npx    | @modelcontextprotocol/server-postgres@0.6.2                 | PostgreSQL, POSTGRES_URL |
| redis               | npx    | @modelcontextprotocol/server-redis@2025.4.25                | Redis, REDIS_URL         |
| supabase            | npx    | @supabase/mcp-server@0.2.0                                  | SUPABASE_TOKEN           |
| gemini-cli          | npx    | mcp-gemini-cli@0.3.1                                        | -                        |
| context7            | npx    | @upstash/context7-mcp@2.0.1                                 | CONTEXT7_API_KEY         |

## Files

| File                                           | Purpose                               |
| ---------------------------------------------- | ------------------------------------- |
| `~/.claude/scripts/mcp-health-check.sh`        | Main health check script              |
| `~/.claude/scripts/mcp-monitor-integration.sh` | Integration with tri-agent monitoring |
| `~/.claude/scripts/mcp-health-check.service`   | Systemd service unit                  |
| `~/.claude/scripts/mcp-health-check.timer`     | Systemd timer for periodic checks     |
| `~/.claude/logs/mcp/mcp-health.log`            | Health check logs                     |
| `~/.claude/metrics/mcp-health.prom`            | Prometheus metrics                    |
| `~/.claude/state/mcp-health-state.json`        | Current health state                  |

## Quick Start

### Run All Health Checks

```bash
~/.claude/scripts/mcp-health-check.sh
```

### Check Specific Server

```bash
~/.claude/scripts/mcp-health-check.sh --server github
~/.claude/scripts/mcp-health-check.sh --server postgres
```

### Enable Auto-Recovery

```bash
~/.claude/scripts/mcp-health-check.sh --auto-recover
```

### Continuous Monitoring

```bash
~/.claude/scripts/mcp-health-check.sh --watch --interval 30 --auto-recover
```

### Export Prometheus Metrics

```bash
~/.claude/scripts/mcp-health-check.sh --format prometheus
```

### JSON Output for Integration

```bash
~/.claude/scripts/mcp-health-check.sh --format json | jq .
```

## Command Reference

```
Usage: mcp-health-check.sh [OPTIONS]

OPTIONS:
    -h, --help              Show help message
    -v, --verbose           Enable verbose output
    -s, --server <name>     Check specific server only
    -f, --format <format>   Output format: text, json, prometheus
    -o, --output <file>     Write output to file
    -a, --auto-recover      Enable auto-recovery for failed servers
    -w, --watch             Continuous monitoring mode
    -i, --interval <secs>   Watch interval in seconds (default: 60)
    --list                  List all configured MCP servers

EXIT CODES:
    0 - All servers healthy
    1 - Some servers have warnings
    2 - Critical issues detected
    3 - Configuration error
```

## Health Check Process

Each MCP server goes through the following checks:

1. **Runner Availability** - Verify npx/uvx is installed
2. **Environment Variables** - Check required env vars are set
3. **External Dependencies** - Test connectivity to PostgreSQL, Redis, etc.
4. **Package Resolution** - Verify npm package is resolvable (verbose mode only)

### Health States

| State    | Meaning            | Action                       |
| -------- | ------------------ | ---------------------------- |
| OK       | Server is healthy  | None required                |
| WARN     | Non-critical issue | Review and address           |
| ERROR    | Server unavailable | Auto-recovery attempted      |
| CRITICAL | Severe failure     | Immediate attention required |

## Auto-Recovery

When `--auto-recover` is enabled, the system attempts to recover failed servers:

1. **NPX Servers**: Clears npm cache and pre-fetches the package
2. **UVX Servers**: Reinstalls the uvx tool
3. **External Services**: Attempts to restart PostgreSQL/Redis (if permissions allow)

Recovery is limited to 3 attempts per server per session to prevent infinite loops.

## Integration with Tri-Agent Monitoring

### Run Integrated Check

```bash
~/.claude/scripts/mcp-monitor-integration.sh
```

### What Integration Does

1. Runs MCP health checks
2. Exports Prometheus metrics to `~/.claude/metrics/mcp-health.prom`
3. Appends metrics to main `~/.claude/metrics/current.prom`
4. Sends alerts via desktop notifications, Slack (if configured)
5. Logs to `~/.claude/logs/mcp-health.log`

## Systemd Installation (Optional)

### Install Service and Timer

```bash
# Copy service files
sudo cp ~/.claude/scripts/mcp-health-check.service /etc/systemd/system/
sudo cp ~/.claude/scripts/mcp-health-check.timer /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable and start timer
sudo systemctl enable mcp-health-check.timer
sudo systemctl start mcp-health-check.timer

# Check status
systemctl status mcp-health-check.timer
systemctl list-timers | grep mcp
```

### User-Level Systemd (No Root Required)

```bash
mkdir -p ~/.config/systemd/user

cp ~/.claude/scripts/mcp-health-check.service ~/.config/systemd/user/
cp ~/.claude/scripts/mcp-health-check.timer ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable mcp-health-check.timer
systemctl --user start mcp-health-check.timer
```

## Prometheus Metrics

### Available Metrics

```prometheus
# Server health status (0=unknown, 1=ok, 2=warn, 3=error, 4=critical)
mcp_server_health{server="git"} 1
mcp_server_health{server="github"} 1
mcp_server_health{server="postgres"} 3

# Check latency in milliseconds
mcp_server_latency_ms{server="git"} 42
mcp_server_latency_ms{server="github"} 156

# Aggregate metrics
mcp_servers_total 13
mcp_servers_healthy 11
mcp_health_check_timestamp 1737466800
```

### Grafana Dashboard Query Examples

```promql
# Percentage of healthy servers
(mcp_servers_healthy / mcp_servers_total) * 100

# Servers with errors
mcp_server_health == 3

# Average check latency
avg(mcp_server_latency_ms)

# Alert: Any server down for > 5 minutes
mcp_server_health > 2 and rate(mcp_server_health[5m]) == 0
```

## Alert Configuration

Edit `~/.claude/alerts.conf`:

```bash
# MCP Alert Configuration
ALERT_LEVEL_THRESHOLD="warning"
DESKTOP_NOTIFY_ENABLED=true
SLACK_WEBHOOK_URL=""             # Optional: Slack webhook
ALERT_EMAIL=""                   # Optional: Email address
SOUND_ENABLED=true               # Play sound for critical alerts
```

## Troubleshooting

### Server Shows ERROR Status

1. Check environment variables: `env | grep -E 'GITHUB|POSTGRES|REDIS|SUPABASE|CONTEXT7'`
2. Verify external service is running: `systemctl status postgresql redis`
3. Test package manually: `npx -y @modelcontextprotocol/server-github --help`

### Auto-Recovery Not Working

- Recovery is limited to 3 attempts per session
- Check logs: `tail -f ~/.claude/logs/mcp/mcp-health.log`
- Run with verbose: `./mcp-health-check.sh -v --auto-recover`

### Prometheus Metrics Not Updating

- Check timer status: `systemctl --user status mcp-health-check.timer`
- Run manual export: `./mcp-health-check.sh --format prometheus`
- Verify metrics file: `cat ~/.claude/metrics/mcp-health.prom`

### Permission Issues

```bash
# Ensure scripts are executable
chmod +x ~/.claude/scripts/mcp-*.sh

# Check log directory permissions
ls -la ~/.claude/logs/mcp/
```

## Cron Alternative

If systemd is not available, use cron:

```bash
# Edit crontab
crontab -e

# Add health check every 5 minutes
*/5 * * * * /home/aadel/.claude/scripts/mcp-monitor-integration.sh >> /home/aadel/.claude/logs/mcp/cron.log 2>&1
```

## Best Practices

1. **Environment Variables**: Always set required env vars in `~/.bashrc` or `~/.profile`
2. **Regular Monitoring**: Enable systemd timer or cron for continuous monitoring
3. **Alert Configuration**: Configure Slack webhook for team notifications
4. **Log Rotation**: Logs are auto-rotated by the cleanup script; run `~/.claude/scripts/cleanup.sh`
5. **Metrics Integration**: Export to Prometheus/Grafana for historical tracking

---

Ahmed Adel Bakr Alderai
