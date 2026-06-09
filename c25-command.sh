#!/bin/bash
# C25 TERMINAL COMMAND CENTER
# Usage: c25 [command]

MCP_ROOT="$HOME/.c25_mcp"
AGENT_REGISTRY="$MCP_ROOT/agents/registry.json"

show_help() {
  cat << HELP
🌌 PLANETARY AGENTS COMMAND CENTER
=================================

USAGE:
  c25 <command> [args]

COMMANDS:
  deploy [path]           Run 25-step autonomous deployment
  status                  Show all agents status
  sync                    Sync Termux & internal storage
  agent <id> <task>       Deploy specific agent with task
  list                    List all 25 agents in order
  logs                    View deployment logs
  mcp                     Start MCP server
  help                    Show this help

EXAMPLES:
  c25 deploy ~/myproject
  c25 agent agent-01 "Build VideoCourts backend"
  c25 status
  c25 sync

AGENTS (1-25):
  01:Architect    06:Security     11:Frontend     16:Legal
  02:Builder      07:Forensics    12:Backend      17:Finance
  03:QA           08:Optimizer    13:Mobile       18:Marketing
  04:Deployer     09:Integrator   14:DevOps       19:Support
  05:Monitor      10:Database     15:Docs         20:Analytics
  21:ML           22:Blockchain   23:IoT          24:Cloud
  25:Coordinator

HELP
}

case "${1:-help}" in
  deploy)
    echo "🚀 Starting 25-step autonomous deployment..."
    bash "$MCP_ROOT/25step_autonomous_deploy.sh" "${2:-$HOME/sovereign_empire}"
    ;;
  
  status)
    echo "📊 Planetary Agents Status"
    echo "=========================="
    if command -v jq &>/dev/null && [[ -f "$AGENT_REGISTRY" ]]; then
      jq -r '.agents[] | "\(.id): \(.name) (\(.role))"' "$AGENT_REGISTRY"
    fi
    echo ""
    echo "Active processes:"
    ps aux | grep -E 'node|python|mongod|tmux' | grep -v grep | head -10 || echo "None"
    ;;
  
  sync)
    echo "🔄 Synchronizing storage..."
    mkdir -p /sdcard/C25_Agents/backup
    cp -r "$MCP_ROOT"/* /sdcard/C25_Agents/backup/ 2>/dev/null || true
    find /sdcard -name "*c25*" -o -name "*agent*" 2>/dev/null | head -20 | while read f; do
      cp -r "$f" "$MCP_ROOT/storage/" 2>/dev/null || true
    done
    echo "✓ Sync complete"
    ;;
  
  agent)
    if [[ -z "${2:-}" || -z "${3:-}" ]]; then
      echo "Usage: c25 agent <agent-id> <task>"
      echo "Example: c25 agent agent-01 \"Build backend\""
      exit 1
    fi
    AGENT_SCRIPT="$MCP_ROOT/agents/${2}/deploy.sh"
    if [[ -f "$AGENT_SCRIPT" ]]; then
      bash "$AGENT_SCRIPT" "${3:-}"
    else
      echo "⚠️ Agent ${2} not found"
    fi
    ;;
  
  list)
    echo "🌌 PLANETARY AGENTS - BUILD SEQUENCE"
    echo "===================================="
    if [[ -f "$AGENT_REGISTRY" ]]; then
      jq -r '.agents[] | "\(.priority). \(.name) (@\(.id)) - \(.role)"' "$AGENT_REGISTRY"
    fi
    ;;
  
  logs)
    echo "📝 Recent deployment logs:"
    ls -lt "$MCP_ROOT/logs/"*.log 2>/dev/null | head -5 | while read f; do
      echo "--- $f ---"
      tail -20 "$f"
    done || echo "No logs found"
    ;;
  
  mcp)
    echo "🔌 Starting MCP Server..."
    cd "$MCP_ROOT/servers"
    ts-node planetary-agents-mcp.ts
    ;;
  
  help|*)
    show_help
    ;;
esac
