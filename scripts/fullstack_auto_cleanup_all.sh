#!/bin/bash

# =========================================
# Full-Stack Fully Automated Cleanup Script
# Deletes Azure resources and MongoDB Atlas cluster
# =========================================

RESOURCE_GROUP="fullstack-rg"
ATLAS_PUBLIC_KEY="<YOUR_ATLAS_PUBLIC_KEY>"
ATLAS_PRIVATE_KEY="<YOUR_ATLAS_PRIVATE_KEY>"
ATLAS_PROJECT_ID="<YOUR_ATLAS_PROJECT_ID>"
ATLAS_CLUSTER_NAME="FullStackCluster"
DB_USERNAME="fullstackuser"

# ---------------- Functions ----------------

cleanup_azure() {
    echo "☁️ Deleting Azure resource group '$RESOURCE_GROUP'..."
    az login --only-show-errors
    az group delete --name $RESOURCE_GROUP --yes --no-wait
    echo "✅ Azure cleanup initiated."
}

cleanup_mongodb() {
    echo "🗑️ Deleting MongoDB Atlas cluster '$ATLAS_CLUSTER_NAME'..."
    
    # Delete cluster
    CLUSTER_EXISTS=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME" | jq -r '.name')

    if [[ "$CLUSTER_EXISTS" == "$ATLAS_CLUSTER_NAME" ]]; then
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X DELETE "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/clusters/$ATLAS_CLUSTER_NAME"
        echo "Cluster deletion initiated."
    else
        echo "Cluster $ATLAS_CLUSTER_NAME does not exist."
    fi

    # Delete DB user
    USER_EXISTS=$(curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
        "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers?username=$DB_USERNAME" | jq -r '.[0].username')

    if [[ "$USER_EXISTS" == "$DB_USERNAME" ]]; then
        curl -s -u "$ATLAS_PUBLIC_KEY:$ATLAS_PRIVATE_KEY" \
            -X DELETE "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_PROJECT_ID/databaseUsers/admin/$DB_USERNAME"
        echo "Database user deleted."
    else
        echo "Database user $DB_USERNAME does not exist."
    fi

    echo "✅ MongoDB Atlas cleanup initiated."
}

# ---------------- Main ----------------

echo "==============================="
echo " FULL-STACK AUTOMATED CLEANUP "
echo "==============================="

cleanup_azure
cleanup_mongodb

echo "==============================="
echo "       CLEANUP INITIATED       "
echo "==============================="
echo "Note: Azure resource group and MongoDB cluster deletion may take a few minutes."
