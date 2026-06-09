#!/bin/bash
# 25-STEP AUTONOMOUS DEPLOYMENT SCRIPT
# For Planetary Agents MCP Server

set -euo pipefail

PROJECT_PATH="${1:-$HOME/sovereign_empire}"
LOG_FILE="$HOME/.c25_mcp/logs/deploy_$(date +%Y%m%d_%H%M%S).log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🚀 INITIATING 25-STEP AUTONOMOUS DEPLOYMENT"
log "Project: $PROJECT_PATH"

# --- PHASE 1: ENVIRONMENT & SETUP (1-5) ---
log "=== PHASE 1: Environment Setup ==="

# 1. Storage permissions
log "[1/25] Requesting storage access..."
termux-setup-storage 2>/dev/null || true

# 2. System update
log "[2/25] Updating system packages..."
pkg update && pkg upgrade -y 2>&1 | tee -a "$LOG_FILE"

# 3. Install dependencies
log "[3/25] Installing core dependencies..."
pkg install -y nodejs-lts git mongodb-bin python3 redis openssh tmux curl jq 2>&1 | tee -a "$LOG_FILE"

# 4. Create deployment directory
log "[4/25] Creating deployment structure..."
mkdir -p "$PROJECT_PATH"/{backend,frontend,data,logs}

# 5. Copy code from storage
log "[5/25] Syncing from internal storage..."
if [[ -d /sdcard/C25_Agents/project ]]; then
  cp -r /sdcard/C25_Agents/project/* "$PROJECT_PATH/" 2>/dev/null || true
  log "✓ Synced from /sdcard"
fi

# --- PHASE 2: BACKEND SETUP (6-12) ---
log "=== PHASE 2: Backend Configuration ==="

# 6. Navigate to backend
cd "$PROJECT_PATH/backend" 2>/dev/null || mkdir -p "$PROJECT_PATH/backend" && cd "$PROJECT_PATH/backend"

# 7. Clean install
log "[7/25] Preparing backend environment..."
rm -rf node_modules package-lock.json 2>/dev/null || true

# 8. Install dependencies
log "[8/25] Installing backend dependencies..."
if [[ -f package.json ]]; then
  npm install --silent 2>&1 | tee -a "$LOG_FILE"
else
  # Create minimal backend
  cat > package.json << 'PKGJSON'
{
  "name": "c25-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.0.0",
    "cors": "^2.8.5"
  }
}
PKGJSON
  npm install --silent
fi

# 9. Configure environment
log "[9/25] Configuring environment variables..."
cat > .env << 'ENVFILE'
PORT=3000
DB_URL=mongodb://127.0.0.1:27017/c25_app
NODE_ENV=production
API_KEY=c25_autonomous_deploy_key
ENVFILE

# 10. Create server file if missing
if [[ ! -f server.js ]]; then
  cat > server.js << 'SERVERJS'
const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ status: 'C25 Planetary Agents Online', timestamp: new Date() });
});

app.get('/api/agents', (req, res) => {
  res.json({ agents: 25, status: 'active' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 C25 Backend running on port ${PORT}`);
});
SERVERJS
fi

# --- PHASE 3: DATABASE AUTOMATION (13-16) ---
log "=== PHASE 3: Database Setup ==="

# 13. Create DB directories
log "[13/25] Creating database storage..."
mkdir -p ~/data/db

# 14. Start MongoDB
log "[14/25] Starting MongoDB..."
mongod --dbpath ~/data/db --fork --logpath ~/data/mongodb.log 2>&1 | tee -a "$LOG_FILE" || true

# 15. Wait for initialization
log "[15/25] Waiting for database..."
sleep 5

# 16. Initialize collections
log "[16/25] Creating collections..."
mongosh c25_app --eval "db.createCollection('agents')" 2>/dev/null || true
mongosh c25_app --eval "db.createCollection('tasks')" 2>/dev/null || true

# --- PHASE 4: FRONTEND BUILD (17-21) ---
log "=== PHASE 4: Frontend Build ==="

# 17. Navigate to frontend
cd "$PROJECT_PATH/frontend" 2>/dev/null || mkdir -p "$PROJECT_PATH/frontend" && cd "$PROJECT_PATH/frontend"

# 18. Clean frontend
log "[18/25] Preparing frontend..."
rm -rf node_modules package-lock.json dist build 2>/dev/null || true

# 19. Install frontend deps
log "[19/25] Installing frontend dependencies..."
if [[ -f package.json ]]; then
  npm install --silent 2>&1 | tee -a "$LOG_FILE"
else
  # Create minimal frontend
  cat > package.json << 'PKGJSON'
{
  "name": "c25-frontend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Build complete'",
    "start": "python3 -m http.server 8080"
  }
}
PKGJSON
  npm install --silent
fi

# 20. Build frontend
log "[20/25] Building frontend..."
npm run build 2>&1 | tee -a "$LOG_FILE" || echo "Build skipped"

# 21. Deploy static assets
log "[21/25] Deploying static assets..."
mkdir -p "$PROJECT_PATH/backend/public"
if [[ -d dist ]]; then
  cp -r dist/* "$PROJECT_PATH/backend/public/" 2>/dev/null || true
elif [[ -d build ]]; then
  cp -r build/* "$PROJECT_PATH/backend/public/" 2>/dev/null || true
fi

# --- PHASE 5: PRODUCTION DEPLOYMENT (22-25) ---
log "=== PHASE 5: Production Launch ==="

# 22. Navigate back to backend
cd "$PROJECT_PATH/backend"

# 23. Install tmux for persistence
log "[23/25] Installing tmux..."
pkg install -y tmux 2>&1 | tee -a "$LOG_FILE" || true

# 24. Start server in tmux
log "[24/25] Launching production server..."
tmux kill-session -t c25_prod 2>/dev/null || true
tmux new-session -d -s c25_prod 'cd '"$PROJECT_PATH"'/backend && npm start'
sleep 3

# 25. Verify deployment
log "[25/25] Verifying deployment..."
sleep 2
if curl -s http://localhost:3000 | grep -q "C25"; then
  log "✅ DEPLOYMENT SUCCESSFUL"
  log "🌐 Backend: http://localhost:3000"
  log "📊 Frontend: http://localhost:8080 (if running)"
  log "💾 Database: mongodb://127.0.0.1:27017/c25_app"
  log "📝 Logs: $LOG_FILE"
  log "🔄 Access server: tmux attach -t c25_prod"
else
  log "⚠️ Server may not be responding. Check logs: $LOG_FILE"
fi

log "========================================="
log "🎉 25-STEP DEPLOYMENT COMPLETE"
log "========================================="

# Sync to storage
cp "$LOG_FILE" /sdcard/C25_Agents/logs/ 2>/dev/null || true

echo "Deployment complete. Run 'tmux attach -t c25_prod' to view server."
