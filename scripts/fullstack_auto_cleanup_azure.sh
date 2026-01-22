#!/bin/bash

# =========================================
# Full-Stack Fully Automated Azure Cleanup
# Deletes all Azure resources in the resource group
# =========================================

RESOURCE_GROUP="fullstack-rg"

echo "☁️ Starting automated Azure cleanup..."
echo "Deleting Azure Resource Group '$RESOURCE_GROUP' and all associated resources..."

az login --only-show-errors

az group delete --name $RESOURCE_GROUP --yes --no-wait

echo "✅ Azure cleanup initiated."
echo "Note: It may take a few minutes for Azure to fully remove all resources."
