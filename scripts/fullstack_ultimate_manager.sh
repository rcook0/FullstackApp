#!/bin/bash

# =========================================
# Full-Stack Ultimate Manager
# Interactive and fully automated modes
# =========================================

FULLSTACK_DIR="./fullstack-app"
LOCAL_WAIT=5
RESOURCE_GROUP="fullstack-rg"
LOCATION="eastus"
ACR_NAME="fullstackregistry$RANDOM"
PLAN_NAME="fullstack-plan"
BACKEND_APP="fullstack-backend"
FRONTEND_APP="fullstack-frontend"
MONGO_URI="<YOUR_MONGO_URI>"  # <-- Replace with your cloud MongoDB URI
JWT_SECRET="your_jwt_secret_here"

MODE="interactive"  # default mode
if [[ "$1" == "auto" ]]; then MODE="auto"; fi

# ----------- Functions -----------

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
    echo "✅ Local Docker containers running."
}

stop_local() {
    echo "🛑 Stopping local Docker containers..."
    docker-compose -f $FULLSTACK_DIR/docker-compose.yml down
    echo "✅ Local Docker stopped."
}

cleanup_local() {
    echo "🧹 Cleaning up local Docker images..."
    docker image prune -f
    echo "✅ Local cleanup done."
}

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

cleanup_azure() {
    echo "☁️ Cleaning up Azure resources..."
    az login --only-show-errors
    az group delete --name $RESOURCE_GROUP --yes --no-wait
    echo "✅ Azure cleanup initiated."
}

# ----------- Main -----------

if [[ "$MODE" == "auto" ]]; then
    echo "==============================="
    echo " FULL-STACK AUTO DEPLOY START "
    echo "==============================="
    generate_local
    zip_local
    start_local
    build_push_docker
    deploy_azure
    stop_local
    cleanup_local
    echo "==============================="
    echo "       DEPLOYMENT FINISHED     "
    echo "==============================="
else
    # Interactive Menu
    echo "==============================="
    echo " FULL-STACK ULTIMATE MANAGER "
    echo "==============================="
    echo "1) Generate local project"
    echo "2) Zip local project"
    echo "3) Start local Docker"
    echo "4) Stop local Docker"
    echo "5) Deploy/Update Azure"
    echo "6) Cleanup Azure"
    echo "7) Cleanup local Docker images"
    echo "8) Exit"
    read -p "Choose an option [1-8]: " choice

    case $choice in
        1) generate_local ;;
        2) zip_local ;;
        3) start_local ;;
        4) stop_local ;;
        5) build_push_docker; deploy_azure ;;
        6) cleanup_azure ;;
        7) cleanup_local ;;
        8) exit 0 ;;
        *) echo "Invalid choice." ;;
    esac
fi
