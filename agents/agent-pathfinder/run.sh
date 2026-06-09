#!/bin/bash
# PathFinder Agent - AI-Powered File Analysis
# Usage: agent-pathfinder [scan|suggest|analyze|locate] [file/path]

set -euo pipefail

AGENT_NAME="PathFinder"
LOG_FILE="$HOME/.c25_pathfinder.log"
LLM_BACKEND="${LLM_BACKEND:-ollama}"  # ollama, qwen, claude-local
LLM_MODEL="${LLM_MODEL:-qwen2.5-coder:7b}"

log() { echo "[$(date '+%H:%M:%S')] [PathFinder] $1" | tee -a "$LOG_FILE"; }

# Analyze file with local LLM
analyze_file_with_llm() {
  local file="$1"
  local prompt="$2"
  
  if [[ ! -f "$file" ]]; then
    log "❌ File not found: $file"
    return 1
  fi
  
  local content=$(head -100 "$file")  # First 100 lines for context
  
  log "🧠 Analyzing: $file with $LLM_BACKEND ($LLM_MODEL)"
  
  case "$LLM_BACKEND" in
    ollama)
      response=$(ollama run "$LLM_MODEL" "$prompt

File to analyze:
$content" 2>/dev/null)
      ;;
    qwen)
      # Qwen local API call
      response=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"$LLM_MODEL\", \"prompt\": \"$prompt\n\nFile:\n$content\", \"stream\": false}" \
        2>/dev/null | jq -r '.response' 2>/dev/null || echo "Analysis pending")
      ;;
    claude-local)
      # Claude local via API
      response=$(curl -s http://localhost:5000/v1/complete \
        -d "{\"prompt\": \"$prompt\n\nFile:\n$content\", \"model\": \"claude\"}" \
        2>/dev/null | jq -r '.choices[0].text' 2>/dev/null || echo "Analysis pending")
      ;;
    *)
      response="Unknown LLM backend: $LLM_BACKEND"
      ;;
  esac
  
  echo "$response"
}

# Suggest improvements for a file
suggest_improvements() {
  local file="$1"
  
  local prompt="You are an expert code reviewer. Analyze this file and provide:
1. What's missing or incomplete
2. Better approaches or formats to use
3. Specific improvements with code examples
4. Potential issues or bugs

Be concise and practical. Format as:
- MISSING: [what's missing]
- BETTER: [better approach]
- FIX: [specific fix]"

  analyze_file_with_llm "$file" "$prompt"
}

# Locate files matching pattern
locate_files() {
  local pattern="$1"
  local search_dir="${2:-$HOME}"
  
  log "🔍 Searching for: $pattern in $search_dir"
  
  find "$search_dir" -type f -iname "*$pattern*" 2>/dev/null | head -20
}

# Scan directory and index files
scan_directory() {
  local dir="$1"
  local output="${2:-$HOME/.c25_pathfinder_index.json}"
  
  log "📂 Scanning directory: $dir"
  
  # Create index
  echo '{"files":[' > "$output"
  
  local first=true
  find "$dir" -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.json" -o -name "*.md" \) 2>/dev/null | head -100 | while read file; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo "," >> "$output"
    fi
    
    local rel_path="${file#$dir/}"
    local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    local modified=$(stat -c%y "$file" 2>/dev/null | cut -d' ' -f1)
    
    echo -n "{\"path\":\"$file\",\"relative\":\"$rel_path\",\"size\":$size,\"modified\":\"$modified\"}" >> "$output"
  done
  
  echo ']}' >> "$output"
  
  log "✅ Index created: $output"
}

# Main command handler
case "${1:-help}" in
  scan)
    scan_directory "${2:-$HOME}" "${3:-$HOME/.c25_pathfinder_index.json}"
    ;;
  suggest)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: agent-pathfinder suggest <file>"
      exit 1
    fi
    suggest_improvements "$2"
    ;;
  analyze)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: agent-pathfinder analyze <file>"
      exit 1
    fi
    analyze_file_with_llm "$2" "Analyze this file and explain what it does, what's missing, and how to improve it."
    ;;
  locate)
    locate_files "${2:-}" "${3:-$HOME}"
    ;;
  help|*)
    cat << HELP
🔍 PathFinder Agent - AI-Powered File Analysis

USAGE:
  agent-pathfinder [command] [args]

COMMANDS:
  scan [dir] [output]     Scan directory and create file index
  suggest <file>          Get AI suggestions for improving a file
  analyze <file>          Analyze file with LLM
  locate <pattern> [dir]  Find files matching pattern

EXAMPLES:
  agent-pathfinder scan ~/videocourts-unified
  agent-pathfinder suggest ~/videocourts-unified/client/src/App.tsx
  agent-pathfinder analyze ~/videocourts-unified/TODO.manifest
  agent-pathfinder locate "TODO" ~/videocourts-unified

CONFIGURATION:
  LLM_BACKEND: ollama|qwen|claude-local (default: ollama)
  LLM_MODEL: Model name (default: qwen2.5-coder:7b)

INTEGRATION:
  - Works with Ranger via :pathfinder_suggest command
  - Auto-scans on file open in Ranger
  - Provides "Did you mean?" suggestions

HELP
    ;;
esac
