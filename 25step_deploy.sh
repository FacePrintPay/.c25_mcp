#!/bin/bash
# 25-Step Autonomous Deployment - Minimal
set -euo pipefail
PROJ="${1:-$HOME}"
log(){ echo "[$(date +%H:%M:%S)] $1"; }
log "🚀 Deploy: $PROJ"
termux-setup-storage 2>/dev/null||true
pkg install -y nodejs-lts git python3 tmux 2>&1|tail -1
mkdir -p "$PROJ"/{backend,frontend}
cd "$PROJ/backend" 2>/dev/null||mkdir -p "$PROJ/backend"&&cd "$PROJ/backend"
[[ -f package.json ]]||echo '{"name":"c25","main":"server.js","scripts":{"start":"node server.js"},"dependencies":{"express":"^4.18.2"}}'>package.json&&npm install --silent
[[ -f server.js ]]||echo "require('express')().listen(3000,()=>console.log('🚀 C25 on :3000'))">server.js
pkg install -y tmux 2>/dev/null||true
tmux kill-session -t c25 2>/dev/null||true
tmux new-session -d -s c25 "cd $PROJ/backend&&npm start"
sleep 2
curl -s localhost:3000&&log "✅ Live"||log "⚠️ Starting..."
log "🎉 Done. Attach: tmux attach -t c25"
