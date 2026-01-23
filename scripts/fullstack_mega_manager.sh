#!/bin/bash
set -euo pipefail

# =========================================
# Full-Stack Mega Manager (FINAL READY)
# - Modes: interactive (default) | auto | cleanup
# - Features: preflight check, optional local Mongo, Atlas provisioning (with wait),
#   local project generation (backend+frontend), docker-compose, local run,
#   build/push to ACR, Azure App Service deploy, cleanup.
# =========================================

# ---------------- User Config (EDIT THESE) ----------------
FULLSTACK_DIR="./fullstack-app"
LOCAL_WAIT=5
RESOURCE_GROUP="fullstack-rg"
LOCATION="eastus"
# Must be globally unique; will append a random suffix if left default below
ACR_NAME_BASE="fullstackregistry"
PLAN_NAME="fullstack-plan"
BACKEND_APP="fullstack-backend"
FRONTEND_APP="fullstack-frontend"

# MongoDB Atlas API keys (REQUIRED if using Atlas provisioning)
ATLAS_PUBLIC_KEY="<YOUR_ATLAS_PUBLIC_KEY>"
ATLAS_PRIVATE_KEY="<YOUR_ATLAS_PRIVATE_KEY>"
ATLAS_PROJECT_ID="<YOUR_ATLAS_PROJECT_ID>"
ATLAS_CLUSTER_NAME="FullStackCluster"
DB_USERNAME="fullstackuser"
DB_PASSWORD="FullStackPass123"

# JWT secret for backend
JWT_SECRET="your_jwt_secret_here"

# Use local mongo? set to "true" to have docker-compose connect backend->local mongo container
USE_LOCAL_MONGO=${USE_LOCAL_MONGO:-false}

# ---------------- Pre-flight check ----------------
check_requirements() {
    echo "🔍 Checking required tools..."

    local missing=()
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v docker-compose >/dev/null 2>&1 || missing+=("docker-compose")
    command -v az >/dev/null 2>&1 || missing+=("azure-cli (az)")
    command -v jq >/dev/null 2>&1 || missing+=("jq")

    if [ ${#missing[@]} -ne 0 ]; then
        echo "❌ Missing required tools: ${missing[*]}"
        echo "Please install them and re-run the script."
        echo "Install hints:"
        echo " - Docker: https://docs.docker.com/get-docker/"
        echo " - Docker Compose: https://docs.docker.com/compose/install/"
        echo " - Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
        echo " - jq: https://stedolan.github.io/jq/download/"
        exit 1
    fi

    echo "✅ All required tools found."
}

# ---------------- Mode detection ----------------
MODE="interactive"
if [[ "${1:-}" == "auto" ]]; then MODE="auto"; fi
if [[ "${1:-}" == "cleanup" ]]; then MODE="cleanup"; fi

# ---------------- Helper: safe mkdir ----------------
ensure_dirs() {
    mkdir -p "$FULLSTACK_DIR/backend" "$FULLSTACK_DIR/backend/models" "$FULLSTACK_DIR/backend/routes" "$FULLSTACK_DIR/backend/middleware"
    mkdir -p "$FULLSTACK_DIR/frontend/src" "$FULLSTACK_DIR/frontend/public"
}

# ---------------- MongoDB Atlas provisioning (idempotent, waits for READY) ----------------
provision_mongodb() {
    if [[ -z "$ATLAS_PUBLIC_KEY" || -z "$ATLAS_PRIVATE_KEY" || -z "$ATLAS_PROJECT_ID" ]]; then
        echo "⚠️  Atlas API credentials not set. Skipping Atlas provisioning. Set ATLAS_PUBLIC_KEY/ATLAS_PRIVATE_KEY/ATLAS_PROJECT_ID to provision."
        return 0
    fi

    echo "☁️ Provisioning MongoDB Atlas cluster (idempotent)..."

    # Check cluster exists
    local cluster_info
    cluster_info=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME")

    if [[ $(echo "$cluster_info" | jq -r '.name // empty') != "$ATLAS_CLUSTER_NAME" ]]; then
        echo "Creating cluster $ATLAS_CLUSTER_NAME (M0 free tier)..."
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"$ATLAS_CLUSTER_NAME\",
                \"providerSettings\": {\"providerName\": \"AWS\", \"instanceSizeName\": \"M0\", \"regionName\": \"US_EAST_1\"}
            }" >/dev/null
        echo "Cluster creation initiated."
    else
        echo "Cluster $ATLAS_CLUSTER_NAME already exists."
    fi

    echo "⏳ Waiting for cluster to reach IDLE state..."
    local state=""
    while [[ "$state" != "IDLE" ]]; do
        state=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME" | jq -r '.stateName // empty')
        echo " - cluster state: ${state:-UNKNOWN}"
        if [[ "$state" == "IDLE" ]]; then break; fi
        sleep 15
    done
    echo "✅ Cluster is ready."

    # Create DB user if missing
    local dbuser
    dbuser=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers?username=$DB_USERNAME" | jq -r '.[0].username // empty')

    if [[ "$dbuser" != "$DB_USERNAME" ]]; then
        echo "Creating DB user $DB_USERNAME..."
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers" \
            -H "Content-Type: application/json" \
            -d "{
                \"databaseName\": \"admin\",
                \"username\": \"$DB_USERNAME\",
                \"password\": \"$DB_PASSWORD\",
                \"roles\": [{\"roleName\": \"readWriteAnyDatabase\", \"databaseName\": \"admin\"}]
            }" >/dev/null
        echo "DB user created."
    else
        echo "DB user $DB_USERNAME already exists."
    fi

    # Whitelist 0.0.0.0/0 (for convenience in dev). Adjust for security.
    curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        -X POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/ipAccessList" \
        -H "Content-Type: application/json" \
        -d "[
            {\"ipAddress\": \"0.0.0.0/0\", \"comment\": \"Allow all for dev\"}
        ]" >/dev/null || true

    # Build MONGO_URI
    MONGO_URI="mongodb+srv://$DB_USERNAME:$DB_PASSWORD@$ATLAS_CLUSTER_NAME.mongodb.net/myFirstDatabase?retryWrites=true&w=majority"
    echo "✅ Atlas ready. MONGO_URI set."
}

# ---------------- MongoDB Atlas cleanup ----------------
cleanup_mongodb() {
    if [[ -z "$ATLAS_PUBLIC_KEY" || -z "$ATLAS_PRIVATE_KEY" || -z "$ATLAS_PROJECT_ID" ]]; then
        echo "⚠️  Atlas API credentials not set. Skipping Atlas cleanup."
        return 0
    fi

    echo "🗑️ Cleaning up MongoDB Atlas cluster & user (idempotent)..."

    local cluster_exists
    cluster_exists=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME" | jq -r '.name // empty')

    if [[ "$cluster_exists" == "$ATLAS_CLUSTER_NAME" ]]; then
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X DELETE "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME" >/dev/null
        echo "Cluster deletion initiated."
    else
        echo "Cluster not found; skipping delete."
    fi

    local user_exists
    user_exists=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers?username=$DB_USERNAME" | jq -r '.[0].username // empty')

    if [[ "$user_exists" == "$DB_USERNAME" ]]; then
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X DELETE "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers/admin/$DB_USERNAME" >/dev/null
        echo "DB user deletion initiated."
    else
        echo "DB user not found; skipping."
    fi

    echo "✅ Atlas cleanup requested (async)."
}

# ---------------- Write local project files (backend + frontend + docker-compose) ----------------
generate_local() {
    ensure_dirs
    echo "🚀 Creating backend & frontend starter files..."

    # backend/package.json
    cat > "$FULLSTACK_DIR/backend/package.json" <<'EOL'
{
  "name": "fullstack-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "mongoose": "^7.0.0",
    "dotenv": "^16.0.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.0"
  }
}
EOL

    # backend/server.js
    cat > "$FULLSTACK_DIR/backend/server.js" <<EOL
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 5000;
let mongoUri = process.env.MONGO_URI || '';

if (process.env.USE_LOCAL_MONGO === 'true') {
  mongoUri = 'mongodb://fullstackuser:FullStackPass123@mongo:27017/mydb?authSource=admin';
}

mongoose.connect(mongoUri, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('✅ MongoDB connected'))
  .catch(err => console.error('❌ MongoDB connection error:', err));

app.get('/api', (req, res) => res.json({ message: 'Hello from backend!' }));

app.listen(PORT, () => console.log(\`🚀 Backend running on port \${PORT}\`));
EOL

    # frontend/package.json
    cat > "$FULLSTACK_DIR/frontend/package.json" <<'EOL'
{
  "name": "fullstack-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  }
}
EOL

    # frontend/src/App.js
    mkdir -p "$FULLSTACK_DIR/frontend/src"
    cat > "$FULLSTACK_DIR/frontend/src/App.js" <<'EOL'
import React, { useEffect, useState } from "react";

const API_URL = process.env.REACT_APP_API_URL || "http://localhost:5000/api";

function App() {
  const [message, setMessage] = useState("");

  useEffect(() => {
    fetch(API_URL)
      .then(res => res.json())
      .then(data => setMessage(data.message || JSON.stringify(data)))
      .catch(err => setMessage("Error: " + err));
  }, []);

  return (
    <div style={{ textAlign: "center", marginTop: "50px" }}>
      <h1>Full-Stack App</h1>
      <p>{message}</p>
      <p>Backend API: {API_URL}</p>
    </div>
  );
}

export default App;
EOL

    # frontend/public/index.html minimal
    mkdir -p "$FULLSTACK_DIR/frontend/public"
    cat > "$FULLSTACK_DIR/frontend/public/index.html" <<'EOL'
<!doctype html>
<html>
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Fullstack Frontend</title></head>
  <body><div id="root"></div></body>
</html>
EOL

    # frontend/src/index.js
    cat > "$FULLSTACK_DIR/frontend/src/index.js" <<'EOL'
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
const root = createRoot(document.getElementById('root'));
root.render(<App />);
EOL

    # dockerfiles
    cat > "$FULLSTACK_DIR/backend/Dockerfile" <<'EOL'
FROM node:20
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5000
CMD ["npm", "start"]
EOL

    cat > "$FULLSTACK_DIR/frontend/Dockerfile" <<'EOL'
FROM node:20
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
RUN npm install -g serve
EXPOSE 3000
CMD ["serve", "-s", "build", "-l", "3000"]
EOL

    # docker-compose.yml template (uses USE_LOCAL_MONGO env)
    cat > "$FULLSTACK_DIR/docker-compose.yml" <<EOL
version: "3.9"
services:
  mongo:
    image: mongo:6
    container_name: fullstack-mongo
    restart: unless-stopped
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: fullstackuser
      MONGO_INITDB_ROOT_PASSWORD: FullStackPass123
    volumes:
      - mongo-data:/data/db

  backend:
    build: ./backend
    container_name: fullstack-backend
    ports:
      - "5000:5000"
    environment:
      - USE_LOCAL_MONGO=\${USE_LOCAL_MONGO:-false}
      - MONGO_URI=\${MONGO_URI:-"mongodb+srv://$DB_USERNAME:$DB_PASSWORD@$ATLAS_CLUSTER_NAME.mongodb.net/myFirstDatabase?retryWrites=true&w=majority"}
      - JWT_SECRET=\${JWT_SECRET:-"$JWT_SECRET"}
    depends_on:
      - mongo
    volumes:
      - ./backend:/usr/src/app
    restart: unless-stopped

  frontend:
    build: ./frontend
    container_name: fullstack-frontend
    ports:
      - "3000:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:5000/api
    volumes:
      - ./frontend:/usr/src/app
    stdin_open: true
    tty: true
    restart: unless-stopped

volumes:
  mongo-data:
EOL

    echo "📦 Starter project files written to $FULLSTACK_DIR"
    echo "Note: You can edit frontend/src/App.js and backend/server.js for custom logic."
}

# ---------------- Local controls ----------------
start_local() {
    echo "🐳 Starting local Docker Compose (USE_LOCAL_MONGO=$USE_LOCAL_MONGO)..."
    (cd "$FULLSTACK_DIR" && USE_LOCAL_MONGO="$USE_LOCAL_MONGO" MONGO_URI="${MONGO_URI:-}" JWT_SECRET="$JWT_SECRET" docker-compose up --build -d)
    sleep $LOCAL_WAIT
    echo "✅ Local stack should be available: frontend http://localhost:3000 backend http://localhost:5000"
}

stop_local() {
    echo "🛑 Stopping local Docker Compose..."
    (cd "$FULLSTACK_DIR" && docker-compose down)
    echo "✅ Local stack stopped."
}

cleanup_local() {
    echo "🧹 Pruning local dangling Docker images..."
    docker image prune -f
    echo "✅ Local cleanup done."
}

# ---------------- Azure functions ----------------
build_push_docker() {
    echo "🐳 Building & pushing Docker images to Azure Container Registry..."

    # ensure unique ACR name
    if [[ "$ACR_NAME_BASE" == "fullstackregistry" ]]; then
        ACR_NAME="${ACR_NAME_BASE}$(date +%s | tail -c 5)"
    else
        ACR_NAME="$ACR_NAME_BASE"
    fi

    az login --only-show-errors
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

    if ! az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic
    fi
    az acr login --name "$ACR_NAME"

    # patch frontend App.js API url for production (will be baked at build)
    FRONTEND_API_URL="https://$BACKEND_APP.azurewebsites.net/api"
    sed -i.bak "s|const API_URL = .*|const API_URL = '$FRONTEND_API_URL';|" "$FULLSTACK_DIR/frontend/src/App.js" || true

    docker build -t "$ACR_NAME.azurecr.io/backend:latest" "$FULLSTACK_DIR/backend"
    docker push "$ACR_NAME.azurecr.io/backend:latest"

    docker build -t "$ACR_NAME.azurecr.io/frontend:latest" "$FULLSTACK_DIR/frontend"
    docker push "$ACR_NAME.azurecr.io/frontend:latest"

    echo "✅ Images pushed to $ACR_NAME.azurecr.io"
}

deploy_azure() {
    echo "☁️ Deploying containers to Azure App Service..."

    if ! az appservice plan show --name "$PLAN_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        az appservice plan create --name "$PLAN_NAME" --resource-group "$RESOURCE_GROUP" --sku B1 --is-linux
    fi

    # Backend
    if az webapp show --name "$BACKEND_APP" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        az webapp config container set --name "$BACKEND_APP" --resource-group "$RESOURCE_GROUP" --docker-custom-image-name "$ACR_NAME.azurecr.io/backend:latest"
    else
        az webapp create --resource-group "$RESOURCE_GROUP" --plan "$PLAN_NAME" --name "$BACKEND_APP" --deployment-container-image-name "$ACR_NAME.azurecr.io/backend:latest"
    fi
    az webapp config appsettings set --name "$BACKEND_APP" --resource-group "$RESOURCE_GROUP" --settings MONGO_URI="$MONGO_URI" JWT_SECRET="$JWT_SECRET"

    # Frontend
    if az webapp show --name "$FRONTEND_APP" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        az webapp config container set --name "$FRONTEND_APP" --resource-group "$RESOURCE_GROUP" --docker-custom-image-name "$ACR_NAME.azurecr.io/frontend:latest"
    else
        az webapp create --resource-group "$RESOURCE_GROUP" --plan "$PLAN_NAME" --name "$FRONTEND_APP" --deployment-container-image-name "$ACR_NAME.azurecr.io/frontend:latest"
    fi

    FRONTEND_URL="https://$FRONTEND_APP.azurewebsites.net"
    echo "✅ Azure deployment complete: $FRONTEND_URL"
    # open in browser
    OS="$(uname)"
    if [[ "$OS" == "Linux" ]]; then xdg-open "$FRONTEND_URL"; elif [[ "$OS" == "Darwin" ]]; then open "$FRONTEND_URL"; else powershell.exe Start-Process "$FRONTEND_URL" || true; fi
}

cleanup_azure() {
    echo "☁️ Deleting Azure resource group $RESOURCE_GROUP (async)..."
    az login --only-show-errors
    az group delete --name "$RESOURCE_GROUP" --yes --no-wait
    echo "✅ Azure cleanup initiated."
}

# ---------------- Main execution flow ----------------
check_requirements

if [[ "$MODE" == "auto" ]]; then
    echo "==============================="
    echo " FULL-STACK AUTO DEPLOY START "
    echo "==============================="

    provision_mongodb
    generate_local
    zip -r fullstack-app.zip "$FULLSTACK_DIR" 2>/dev/null || true
    start_local
    build_push_docker
    deploy_azure
    stop_local
    cleanup_local

    echo "==============================="
    echo "       DEPLOYMENT FINISHED     "
    echo "==============================="

elif [[ "$MODE" == "cleanup" ]]; then
    echo "==============================="
    echo " FULL-STACK AUTO CLEANUP START "
    echo "==============================="

    cleanup_azure
    cleanup_mongodb

    echo "==============================="
    echo "       CLEANUP INITIATED       "
    echo "==============================="

else
    # interactive menu
    while true; do
        echo
        echo "==============================="
        echo " FULL-STACK MEGA MANAGER (MENU)"
        echo "==============================="
        echo "1) Full Deployment (Atlas + Local + Azure)"
        echo "2) Start local stack (use USE_LOCAL_MONGO=$USE_LOCAL_MONGO)"
        echo "3) Stop local stack"
        echo "4) Deploy to Azure (build & push images + create webapps)"
        echo "5) Cleanup All (Azure + Atlas)"
        echo "6) Toggle USE_LOCAL_MONGO (current: $USE_LOCAL_MONGO)"
        echo "7) Exit"
        read -p "Choose [1-7]: " choice
        case "$choice" in
            1)
                provision_mongodb
                generate_local
                zip -r fullstack-app.zip "$FULLSTACK_DIR" 2>/dev/null || true
                start_local
                build_push_docker
                deploy_azure
                stop_local
                cleanup_local
                ;;
            2) start_local ;;
            3) stop_local ;;
            4)
                build_push_docker
                deploy_azure
                ;;
            5)
                cleanup_azure
                cleanup_mongodb
                ;;
            6)
                if [[ "$USE_LOCAL_MONGO" == "true" ]]; then USE_LOCAL_MONGO="false"; else USE_LOCAL_MONGO="true"; fi
                echo "USE_LOCAL_MONGO set to $USE_LOCAL_MONGO"
                ;;
            7) echo "Bye."; exit 0 ;;
            *) echo "Invalid choice." ;;
        esac
    done
fi
