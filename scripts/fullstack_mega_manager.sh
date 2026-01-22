#!/bin/bash

# =========================================
# Full-Stack Mega Manager
# Menu + Fully Automated Mode
# MongoDB Atlas + Local Docker + Azure
# =========================================

¤ Option 1 – Full deployment: MongoDB + local + Azure

¤ Option 2 – Cleanup all cloud resources (Azure + MongoDB)

¤ Option 3 – Full rebuild (cleanup + redeploy)

¤ Option 4 – Exit

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
ATLAS_PROJECT_ID="<YOUR_ATLAS_PROJECT_ID>"
ATLAS_CLUSTER_NAME="FullStackCluster"
DB_USERNAME="fullstackuser"

JWT_SECRET="your_jwt_secret_here"

# ---------------- Functions ----------------

# -------- MongoDB Provisioning --------
provision_mongodb() {
    echo "☁️ Provisioning MongoDB Atlas cluster..."

    CLUSTER_EXISTS=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME" | jq -r '.name')

    if [[ "$CLUSTER_EXISTS" != "$ATLAS_CLUSTER_NAME" ]]; then
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"$ATLAS_CLUSTER_NAME\",
                \"providerSettings\": {\"providerName\": \"AWS\", \"instanceSizeName\": \"M0\", \"regionName\": \"US_EAST_1\"}
            }"
        echo "Cluster creation initiated."
    else
        echo "Cluster $ATLAS_CLUSTER_NAME already exists."
    fi

    echo "⏳ Waiting for cluster to be ready..."
    STATUS=""
    while [[ "$STATUS" != "IDLE" ]]; do
        STATUS=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME" | jq -r '.stateName')
        echo "Cluster status: $STATUS"
        if [[ "$STATUS" != "IDLE" ]]; then sleep 15; fi
    done
    echo "✅ Cluster is ready."

    USER_EXISTS=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers?username=$DB_USERNAME" | jq -r '.[0].username')

    if [[ "$USER_EXISTS" != "$DB_USERNAME" ]]; then
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers" \
            -H "Content-Type: application/json" \
            -d "{
                \"databaseName\": \"admin\",
                \"username\": \"$DB_USERNAME\",
                \"password\": \"FullStackPass123\",
                \"roles\": [{\"roleName\": \"readWriteAnyDatabase\", \"databaseName\": \"admin\"}]
            }"
        echo "Database user created."
    else
        echo "Database user $DB_USERNAME already exists."
    fi

    curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        -X POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/ipAccessList" \
        -H "Content-Type: application/json" \
        -d "[
            {\"ipAddress\": \"0.0.0.0/0\", \"comment\": \"Allow all\"}
        ]"

    MONGO_URI="mongodb+srv://$DB_USERNAME:FullStackPass123@$ATLAS_CLUSTER_NAME.mongodb.net/myFirstDatabase?retryWrites=true&w=majority"
    echo "✅ MongoDB Atlas ready: $MONGO_URI"
}

# -------- Local Project --------
generate_local() {
    echo "🚀 Generating local full-stack project..."
    mkdir -p $FULLSTACK_DIR/backend/models $FULLSTACK_DIR/backend/routes $FULLSTACK_DIR/backend/middleware
    mkdir -p $FULLSTACK_DIR/frontend/src
    echo "📦 Local project generated at $FULLSTACK_DIR"
}

zip_local() {
    echo "📦 Creating ZIP archive..."
    zip -r fullstack-app.zip $FULLSTACK_DIR
    echo "✅ ZIP created: fullstack-app.zip"
}

start_local() {
    echo "🐳 Starting local Docker containers..."
    docker-compose -f $FULLSTACK_DIR/docker-compose.yml up --build -d
    sleep $LOCAL_WAIT
    echo "✅ Local Docker running."
}

stop_local() {
    echo "🛑 Stopping local Docker..."
    docker-compose -f $FULLSTACK_DIR/docker-compose.yml down
    echo "✅ Local Docker stopped."
}

cleanup_local() {
    echo "🧹 Cleaning up local Docker images..."
    docker image prune -f
    echo "✅ Local cleanup done."
}

# -------- Azure Deployment --------
build_push_docker() {
    echo "🐳 Building and pushing Docker images to Azure Container Registry..."
    az login --only-show-errors
    az group create --name $RESOURCE_GROUP --location $LOCATION

    if ! az acr show --name $ACR_NAME &> /dev/null; then
        az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic
    fi
    az acr login --name $ACR_NAME

    FRONTEND_API_URL="https://$BACKEND_APP.azurewebsites.net/api"
    sed -i.bak "s|const API_URL = .*|const API_URL = '$FRONTEND_API_URL';|" $FULLSTACK_DIR/frontend/src/App.js

    docker build -t backend $FULLSTACK_DIR/backend
    docker tag backend $ACR_NAME.azurecr.io/backend:latest
    docker push $ACR_NAME.azurecr.io/backend:latest

    docker build -t frontend $FULLSTACK_DIR/frontend
    docker tag frontend $ACR_NAME.azurecr.io/frontend:latest
    docker push $ACR_NAME.azurecr.io/frontend:latest
}

deploy_azure() {
    echo "☁️ Deploying backend & frontend to Azure..."
    if ! az appservice plan show --name $PLAN_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
        az appservice plan create --name $PLAN_NAME --resource-group $RESOURCE_GROUP --sku B1 --is-linux
    fi

    # Backend
    if az webapp show --name $BACKEND_APP --resource-group $RESOURCE_GROUP &> /dev/null; then
        az webapp config container set --name $BACKEND_APP --resource-group $RESOURCE_GROUP --docker-custom-image-name $ACR_NAME.azurecr.io/backend:latest
    else
        az webapp create --resource-group $RESOURCE_GROUP --plan $PLAN_NAME --name $BACKEND_APP --deployment-container-image-name $ACR_NAME.azurecr.io/backend:latest
    fi
    az webapp config appsettings set --name $BACKEND_APP --resource-group $RESOURCE_GROUP --settings MONGO_URI=$MONGO_URI JWT_SECRET=$JWT_SECRET

    # Frontend
    if az webapp show --name $FRONTEND_APP --resource-group $RESOURCE_GROUP &> /dev/null; then
        az webapp config container set --name $FRONTEND_APP --resource-group $RESOURCE_GROUP --docker-custom-image-name $ACR_NAME.azurecr.io/frontend:latest
    else
        az webapp create --resource-group $RESOURCE_GROUP --plan $PLAN_NAME --name $FRONTEND_APP --deployment-container-image-name $ACR_NAME.azurecr.io/frontend:latest
    fi

    FRONTEND_URL="https://$FRONTEND_APP.azurewebsites.net"
    echo "✅ Azure deployment complete! Frontend URL: $FRONTEND_URL"

    OS="$(uname)"
    if [[ "$OS" == "Linux" ]]; then xdg-open "$FRONTEND_URL"
    elif [[ "$OS" == "Darwin" ]]; then open "$FRONTEND_URL"
    elif [[ "$OS" == MINGW* || "$OS" == CYGWIN* || "$OS" == MSYS* ]]; then powershell.exe Start-Process "$FRONTEND_URL"
    else echo "Open your browser manually at $FRONTEND_URL"
    fi
}

# -------- Cleanup --------
cleanup_azure() {
    echo "☁️ Cleaning up Azure resources..."
    az login --only-show-errors
    az group delete --name $RESOURCE_GROUP --yes --no-wait
    echo "✅ Azure cleanup initiated."
}

cleanup_mongodb() {
    echo "🗑️ Cleaning up MongoDB Atlas..."
    CLUSTER_EXISTS=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME" | jq -r '.name')

    if [[ "$CLUSTER_EXISTS" == "$ATLAS_CLUSTER_NAME" ]]; then
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X DELETE "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME"
        echo "Cluster deletion initiated."
    fi

    USER_EXISTS=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers?username=$DB_USERNAME" | jq -r '.[0].username')

    if [[ "$USER_EXISTS" == "$DB_USERNAME" ]]; then
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X DELETE "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers/admin/$DB_USERNAME"
        echo "Database user deleted."
    fi

    echo "✅ MongoDB Atlas cleanup initiated."
}

# -------- Main Menu --------
echo "==============================="
echo " FULL-STACK MEGA MANAGER "
echo "==============================="
echo "1) Full Deployment (MongoDB + Local + Azure)"
echo "2) Cleanup All (Azure + MongoDB)"
echo "3) Full Rebuild (Cleanup + Deploy)"
echo "4) Exit"
read -p "Choose an option [1-4]: " choice

case $choice in
    1)
        provision_mongodb
        generate_local
        zip_local
        start_local
        build_push_docker
        deploy_azure
        stop_local
        cleanup_local
        ;;
    2)
        cleanup_azure
        cleanup_mongodb
        ;;
    3)
        cleanup_azure
        cleanup_mongodb
        provision_mongodb
        generate_local
        zip_local
        start_local
        build_push_docker
        deploy_azure
        stop_local
        cleanup_local
        ;;
    4)
        exit 0
        ;;
    *)
        echo "Invalid choice."
        ;;
esac
