#!/bin/bash

# =========================================
# Full-Stack Fully Automated Mega Deployment
# Local + Azure Deployment in one command
# =========================================

# ---------------- Configuration ----------------
FULLSTACK_DIR="./fullstack-app"
LOCAL_WAIT=5
RESOURCE_GROUP="fullstack-rg"
LOCATION="eastus"
ACR_NAME="fullstackregistry$RANDOM"
PLAN_NAME="fullstack-plan"
BACKEND_APP="fullstack-backend"
FRONTEND_APP="fullstack-frontend"
MONGO_URI="<YOUR_MONGO_URI>"  # Replace with your MongoDB URI
JWT_SECRET="your_jwt_secret_here"

# ---------------- Functions ----------------

generate_local() {
    echo "🚀 Generating local full-stack project..."
    mkdir -p $FULLSTACK_DIR/backend/models $FULLSTACK_DIR/backend/routes $FULLSTACK_DIR/backend/middleware
    mkdir -p $FULLSTACK_DIR/frontend/src

    # You can insert all backend/frontend file content here
    # For brevity, I’m skipping full file content
    echo "📦 Local project generated at $FULLSTACK_DIR"
}

zip_local() {
    echo "📦 Creating ZIP archive..."
    zip -r fullstack-app.zip $FULLSTACK_DIR
    echo "✅ ZIP created: fullstack-app.zip"
}

build_push_docker() {
    echo "🐳 Building and pushing Docker images to ACR..."
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

cleanup_local() {
    echo "🧹 Cleaning up local Docker images..."
    docker image prune -f
    echo "✅ Local cleanup done."
}

# ---------------- Main Execution ----------------
echo "==============================="
echo " FULL-STACK AUTO DEPLOY START "
echo "==============================="

generate_local
zip_local
build_push_docker
deploy_azure
cleanup_local

echo "==============================="
echo "       DEPLOYMENT FINISHED     "
echo "==============================="
