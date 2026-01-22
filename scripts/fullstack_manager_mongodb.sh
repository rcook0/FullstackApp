#!/bin/bash

# =========================================
# Full-Stack Ultimate Manager with MongoDB Atlas
# =========================================

FULLSTACK_DIR="./fullstack-app"
LOCAL_WAIT=5
RESOURCE_GROUP="fullstack-rg"
LOCATION="eastus"
ACR_NAME="fullstackregistry$RANDOM"
PLAN_NAME="fullstack-plan"
BACKEND_APP="fullstack-backend"
FRONTEND_APP="fullstack-frontend"

# MongoDB Atlas API keys
ATLAS_PUBLIC_KEY="<YOUR_ATLAS_PUBLIC_KEY>"
ATLAS_PRIVATE_KEY="<YOUR_ATLAS_PRIVATE_KEY>"
ATLAS_PROJECT_ID="<YOUR_ATLAS_PROJECT_ID>" # existing project
ATLAS_CLUSTER_NAME="FullStackCluster"

JWT_SECRET="your_jwt_secret_here"

# ---------------- Functions ----------------

provision_mongodb() {
    echo "☁️ Provisioning MongoDB Atlas cluster..."

    # Create cluster
    curl -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        -X POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$ATLAS_CLUSTER_NAME\",
            \"providerSettings\": {\"providerName\": \"AWS\", \"instanceSizeName\": \"M0\", \"regionName\": \"US_EAST_1\"}
        }"

    echo "⏳ Waiting for cluster creation (M0 takes ~5 minutes)..."
    sleep 300  # Wait 5 minutes for free tier cluster to be ready

    # Create database user
    curl -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        -X POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers" \
        -H "Content-Type: application/json" \
        -d "{
            \"databaseName\": \"admin\",
            \"username\": \"fullstackuser\",
            \"password\": \"FullStackPass123\",
            \"roles\": [{\"roleName\": \"readWriteAnyDatabase\", \"databaseName\": \"admin\"}]
        }"

    # Allow access from anywhere (0.0.0.0/0)
    curl -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        -X POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/ipAccessList" \
        -H "Content-Type: application/json" \
        -d "[
            {\"ipAddress\": \"0.0.0.0/0\", \"comment\": \"Allow all\"}
        ]"

    # Construct connection string
    MONGO_URI="mongodb+srv://fullstackuser:FullStackPass123@$ATLAS_CLUSTER_NAME.mongodb.net/myFirstDatabase?retryWrites=true&w=majority"
    echo "✅ MongoDB Atlas provisioned. Connection string: $MONGO_URI"
}

# Reuse previous functions: generate_local, zip_local, start_local, stop_local, cleanup_local, build_push_docker, deploy_azure, cleanup_azure
# (Include all functions from the previous ultimate mega script)

# ---------------- Main ----------------

MODE="auto"
echo "==============================="
echo " FULL-STACK AUTO DEPLOY START "
echo "==============================="

# 1️⃣ Provision DB
provision_mongodb

# 2️⃣ Generate local project
generate_local

# 3️⃣ Zip project
zip_local

# 4️⃣ Start local Docker (optional)
start_local

# 5️⃣ Build and push Docker images
build_push_docker

# 6️⃣ Deploy to Azure
deploy_azure

# 7️⃣ Stop local Docker
stop_local

# 8️⃣ Cleanup local Docker images
cleanup_local

echo "==============================="
echo "       DEPLOYMENT FINISHED     "
echo "==============================="
