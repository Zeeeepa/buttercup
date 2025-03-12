#!/bin/bash

usage() {
    echo "Usage: $0 [create|delete] [name] [dns_zone] [resource_group]"
    echo "  create: Creates a new service principal (default: AIxCCSPA if no name provided)"
    echo "          Optionally assign DNS Zone Contributor role if dns_zone and resource_group are provided"
    echo "  delete: Deletes an existing service principal (name required)"
    exit 1
}

# Get command and arguments
COMMAND=${1:-"create"}
SPA_NAME=${2:-"AIxCCSPA"}
DNS_ZONE_NAME=$3
RESOURCE_GROUP=$4

# Validate command
if [[ "$COMMAND" != "create" && "$COMMAND" != "delete" ]]; then
    echo "Error: Invalid command '$COMMAND'"
    usage
fi

# Validate name for delete command
if [[ "$COMMAND" == "delete" && "$SPA_NAME" == "AIxCCSPA" && -z "$2" ]]; then
    echo "Error: Service principal name is required for delete operation"
    usage
fi

# Validate DNS Zone parameters
if [[ -n "$DNS_ZONE_NAME" && -z "$RESOURCE_GROUP" ]] || [[ -z "$DNS_ZONE_NAME" && -n "$RESOURCE_GROUP" ]]; then
    echo "Error: Both DNS zone name and resource group must be provided together"
    usage
fi

# Check if user is logged in
echo "Checking Azure login status..."
if ! az account show &>/dev/null; then
    echo "You are not logged into Azure. Attempting to log in to tenant aixcc.tech..."
    az login --tenant aixcc.tech
    
    # Check if login was successful
    if ! az account show &>/dev/null; then
        echo "Failed to log in to Azure. Please log in manually and try again."
        exit 1
    fi
    echo "Successfully logged in to Azure."
else
    echo "Already logged in to Azure."
fi

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Execute requested command
if [[ "$COMMAND" == "create" ]]; then
    echo "Creating service principal '$SPA_NAME'..."
    
    # Create service principal and capture output as JSON
    SP_JSON=$(az ad sp create-for-rbac --name "$SPA_NAME" --role Contributor --scopes /subscriptions/$SUBSCRIPTION_ID)
    
    # Extract variables from the JSON output
    APP_ID=$(echo "$SP_JSON" | grep -oP '"appId": "\K[^"]+')
    DISPLAY_NAME=$(echo "$SP_JSON" | grep -oP '"displayName": "\K[^"]+')
    PASSWORD=$(echo "$SP_JSON" | grep -oP '"password": "\K[^"]+')
    TENANT=$(echo "$SP_JSON" | grep -oP '"tenant": "\K[^"]+')
    
    # Display the extracted variables with requested naming convention
    echo ""
    echo "Service Principal created successfully:"
    echo "-----------------------------------"
    echo "TF_ARM_CLIENT_ID=\"$APP_ID\""
    echo "TF_ARM_CLIENT_SECRET=\"$PASSWORD\""
    echo "TF_ARM_TENANT_ID=\"$TENANT\""
    echo "TF_ARM_SUBSCRIPTION_ID=\"$SUBSCRIPTION_ID\""
    
    # If DNS Zone name and Resource Group provided, assign DNS Zone Contributor role
    if [[ -n "$DNS_ZONE_NAME" && -n "$RESOURCE_GROUP" ]]; then
        echo ""
        echo "Assigning DNS Zone Contributor role..."
        DNS_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/dnszones/$DNS_ZONE_NAME"
        
        az role assignment create --assignee "$APP_ID" --role "DNS Zone Contributor" --scope "$DNS_SCOPE"
        
        echo "DNS Zone Contributor role assigned for zone: $DNS_ZONE_NAME in resource group: $RESOURCE_GROUP"
    fi
    
    # Export variables for potential use in the current shell
    export TF_ARM_CLIENT_ID="$APP_ID"
    export TF_ARM_CLIENT_SECRET="$PASSWORD"
    export TF_ARM_TENANT_ID="$TENANT"
    export TF_ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
    
    echo ""
    echo "Variables have been exported to your shell environment"
    echo "You can also save these to a .env file for later use:"
    echo 'echo "TF_ARM_CLIENT_ID=\"$TF_ARM_CLIENT_ID\"" > .env'
    echo 'echo "TF_ARM_CLIENT_SECRET=\"$TF_ARM_CLIENT_SECRET\"" >> .env'
    echo 'echo "TF_ARM_TENANT_ID=\"$TF_ARM_TENANT_ID\"" >> .env'
    echo 'echo "TF_ARM_SUBSCRIPTION_ID=\"$TF_ARM_SUBSCRIPTION_ID\"" >> .env'
    
elif [[ "$COMMAND" == "delete" ]]; then
    # Get the service principal ID
    echo "Deleting service principal '$SPA_NAME'..."
    SP_ID=$(az ad sp list --display-name "$SPA_NAME" --query "[0].id" -o tsv)
    
    if [[ -z "$SP_ID" ]]; then
        echo "Error: Service principal '$SPA_NAME' not found"
        exit 1
    fi
    
    # Delete the service principal
    az ad sp delete --id "$SP_ID"
    echo "Service principal '$SPA_NAME' ($SP_ID) deleted successfully"
fi

