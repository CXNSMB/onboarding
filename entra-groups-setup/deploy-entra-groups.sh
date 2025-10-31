#!/bin/bash
#
# Complete Entra ID setup: Groups, Administrative Unit, and Role Assignments
# 
# DESCRIPTION:
#   This unified script creates all required Entra groups, sets up administrative unit,
#   and assigns both Entra directory roles and RBAC roles. All groups are hard-coded 
#   for standalone usage (copy/paste or curl download).
#
# USAGE:
#   ./deploy-entra-groups.sh [-t TENANT_CODE] [-c CONFIG_FILE] [-w] [-e]
#
# OPTIONS:
#   -t, --tenant-code      Tenant code to use for group naming
#   -c, --config-file      Path to the JSON configuration file
#   -w, --whatif           Test mode, no actual changes
#   -e, --entra-only       Only setup Entra ID administrative unit and roles
#   -h, --help             Show this help message
#
# REQUIRES:
#   - Global Admin and Subscription Owner permissions
#   - Azure CLI (az) installed and logged in
#   - jq for JSON parsing (available in Cloud Shell)
#
# AUTHOR: Generated for Lub-LZ
# DATE: October 31, 2025
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHATIF=false
SETUP_ENTRA_ONLY=false
TENANT_CODE=""
CONFIG_FILE=""

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[0m'
readonly NC='\033[0m' # No Color

# Hard-coded group definitions for standalone usage (names without sec-tenant- prefix)
readonly TENANT_GROUPS='[
  {
    "name": "dailyadmin",
    "description": "group for daily operations",
    "roles": ["User Administrator", "Groups Administrator"]
  },
  {
    "name": "elevadmin",
    "description": "group with elevated roles",
    "roles": [
      "User Administrator",
      "Groups Administrator",
      "Security Administrator",
      "Application Administrator",
      "Global Reader",
      "License Administrator",
      "Authentication Administrator",
      "Authentication Policy Administrator",
      "Privileged Authentication Administrator",
      "Conditional Access Administrator"
    ]
  },
  {
    "name": "reservations-read",
    "description": "can read azure reservations",
    "roles": []
  },
  {
    "name": "reservations-admin",
    "description": "can manage azure reservations",
    "roles": []
  },
  {
    "name": "reservations-purchase",
    "description": "can purchase azure reservations",
    "roles": []
  },
  {
    "name": "break-glass",
    "description": "break glass accounts, dynamic, informational",
    "roles": []
  }
]'

readonly SUBSCRIPTION_GROUPS='[
  {
    "name": "reader",
    "description": "Reader on subscription",
    "rbacRoles": ["Reader"]
  },
  {
    "name": "dailyadmin",
    "description": "Daily admin on subscription",
    "rbacRoles": [
      "Reader",
      "Backup Reader",
      "Desktop Virtualization Virtual Machine Contributor",
      "Desktop Virtualization User Session Operator",
      "DNS Zone Contributor"
    ]
  },
  {
    "name": "contributor",
    "description": "Contributor on subscription",
    "rbacRoles": ["Contributor"]
  },
  {
    "name": "costreader",
    "description": "can read cost information",
    "rbacRoles": ["Cost Management Reader"]
  },
  {
    "name": "sec-uaa",
    "description": "Restricted User Access Administrator",
    "rbacRoles": ["User Access Administrator"]
  },
  {
    "name": "owner",
    "description": "Owner on subscription",
    "rbacRoles": ["Owner"]
  }
]'

#
# Helper Functions
#

# Print colored output to stderr
log() {
    local color=$1
    local message=$2
    
    case $color in
        "red")    echo -e "${RED}${message}${NC}" >&2 ;;
        "green")  echo -e "${GREEN}${message}${NC}" >&2 ;;
        "yellow") echo -e "${YELLOW}${message}${NC}" >&2 ;;
        "cyan")   echo -e "${CYAN}${message}${NC}" >&2 ;;
        "white")  echo -e "${WHITE}${message}${NC}" >&2 ;;
        *)        echo "$message" >&2 ;;
    esac
}

# Show usage information
show_usage() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# \?//'
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--tenant-code)
                TENANT_CODE="$2"
                shift 2
                ;;
            -c|--config-file)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -w|--whatif)
                WHATIF=true
                shift
                ;;
            -e|--entra-only)
                SETUP_ENTRA_ONLY=true
                shift
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                log "red" "Unknown option: $1"
                show_usage
                ;;
        esac
    done
}

# Check if required tools are available
check_requirements() {
    log "cyan" "Checking requirements..."
    
    if ! command -v az &> /dev/null; then
        log "red" "Error: Azure CLI (az) is not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log "red" "Error: jq is not installed (required for JSON parsing)"
        exit 1
    fi
    
    # Check if logged in to Azure CLI
    if ! az account show &> /dev/null; then
        log "red" "Error: Not logged in to Azure CLI"
        log "yellow" "Please run: az login --scope https://graph.microsoft.com/.default"
        exit 1
    fi
    
    # Test if we can actually call Graph API (check permissions)
    log "cyan" "Testing Graph API access..."
    local test_result
    test_result=$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/organization" 2>&1)
    
    if echo "$test_result" | grep -q "Authorization_RequestDenied\|Forbidden\|Insufficient privileges"; then
        log "red" ""
        log "red" "❌ Graph API access denied - insufficient permissions"
        log "yellow" ""
        log "yellow" "Your current authentication doesn't have the required Microsoft Graph API permissions."
        log "yellow" "This is common in Azure Cloud Shell due to limited token scope."
        log "yellow" ""
        log "yellow" "Please re-authenticate with Graph API scope:"
        log "white" ""
        log "white" "  az logout"
        log "white" "  az login --scope https://graph.microsoft.com/.default"
        log "white" ""
        log "yellow" "Then run this script again."
        exit 1
    fi
    
    log "green" "✓ All requirements met"
    log "green" "✓ Graph API access confirmed"
}

# Invoke Graph API request - returns JSON to stdout, logs to stderr
graph_request() {
    local method=${1:-GET}
    local uri=$2
    local description=$3
    local body=${4:-}
    local ignore_error=${5:-false}
    
    log "cyan" "Executing: $description"
    
    if [ "$WHATIF" = true ]; then
        log "yellow" "WHATIF: Would execute: $method $uri"
        [ -n "$body" ] && log "yellow" "WHATIF: With body: $body"
        echo "{}"
        return 0
    fi
    
    local cmd=(az rest --method "$method" --uri "$uri")
    [ -n "$body" ] && cmd+=(--body "$body")
    
    if [ "$ignore_error" = true ]; then
        "${cmd[@]}" 2>/dev/null || echo "{}"
    else
        "${cmd[@]}"
    fi
}

# Get current user information
get_current_user() {
    log "cyan" "Getting current user information..."
    
    local user_info
    user_info=$(az ad signed-in-user show 2>/dev/null || echo "{}")
    
    local user_id=$(echo "$user_info" | jq -r '.id')
    if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
        log "red" "Error: Cannot get current user information"
        exit 1
    fi
    
    local display_name=$(echo "$user_info" | jq -r '.displayName')
    local upn=$(echo "$user_info" | jq -r '.userPrincipalName')
    
    log "green" "Current user: $display_name ($upn)"
    echo "$user_info"
}

# Get onmicrosoft.com domain
get_onmicrosoft_domain() {
    log "cyan" "Getting onmicrosoft.com domain..."
    
    local domains
    domains=$(graph_request "GET" \
        "https://graph.microsoft.com/v1.0/domains" \
        "Getting tenant domains" \
        "" \
        "true")
    
    local domain
    domain=$(echo "$domains" | jq -r '.value[] | select(.id | contains(".onmicrosoft.com")) | select(.isInitial == true) | .id' | head -1)
    
    if [ -z "$domain" ] || [ "$domain" = "null" ]; then
        log "yellow" "Warning: Could not find onmicrosoft.com domain"
        echo ""
        return 1
    fi
    
    log "green" "Found onmicrosoft.com domain: $domain"
    echo "$domain"
}

# Load or create configuration
load_config() {
    local config_file=$1
    
    if [ -f "$config_file" ]; then
        log "green" "Found existing config file: $config_file"
        cat "$config_file"
    else
        log "yellow" "Config file does not exist. Will create new config based on TenantCode: $TENANT_CODE"
        echo '{"tenantconfig":{},"subscriptions":{}}'
    fi
}

# Save configuration to file
save_config() {
    local config_file=$1
    local config_json=$2
    
    if [ "$WHATIF" = true ] || [ "$SETUP_ENTRA_ONLY" = true ]; then
        log "yellow" "Configuration not saved (WhatIf or SetupEntraOnly mode)"
        return 0
    fi
    
    echo "$config_json" | jq '.' > "$config_file"
    log "green" "Configuration saved to: $config_file"
}

# Setup Restricted Administrative Unit
setup_restricted_au() {
    local current_user_id=$1
    local tenant_code=$2
    local au_name="$tenant_code-tenant-admin"
    
    log "cyan" ""
    log "cyan" "=== Setting up Restricted Administrative Unit ==="
    
    # Check if AU exists
    local existing_au
    existing_au=$(graph_request "GET" \
        "https://graph.microsoft.com/v1.0/directory/administrativeUnits?\$filter=displayName%20eq%20'$au_name'" \
        "Checking if administrative unit '$au_name' exists" \
        "" \
        "true")
    
    local au_count=$(echo "$existing_au" | jq '.value | length' 2>/dev/null || echo "0")
    local au_id=""
    
    if [ "$au_count" -gt 0 ]; then
        au_id=$(echo "$existing_au" | jq -r '.value[0].id')
        log "yellow" "Administrative Unit '$au_name' already exists (ID: $au_id)"
    else
        if [ "$WHATIF" = true ]; then
            log "yellow" "WHATIF: Would create administrative unit '$au_name'"
            echo ""
            return 0
        fi
        
        # Create new AU
        local au_body
        au_body=$(jq -n \
            --arg name "$au_name" \
            --arg tenantCode "$tenant_code" \
            '{
                displayName: $name,
                description: ("Restricted administrative unit for tenant " + $tenantCode + " management operations"),
                visibility: "HiddenMembership",
                isMemberManagementRestricted: true
            }')
        
        local new_au
        new_au=$(graph_request "POST" \
            "https://graph.microsoft.com/v1.0/directory/administrativeUnits" \
            "Creating administrative unit '$au_name'" \
            "$au_body" \
            "true")
        
        au_id=$(echo "$new_au" | jq -r '.id' 2>/dev/null || echo "")
        
        if [ -z "$au_id" ] || [ "$au_id" = "null" ]; then
            log "yellow" ""
            log "yellow" "⚠️  Could not create Administrative Unit automatically"
            log "yellow" "   This likely means insufficient Graph API permissions."
            log "yellow" ""
            log "yellow" "📋 Manual steps required:"
            log "yellow" "   1. Go to Azure Portal → Entra ID → Administrative Units"
            log "yellow" "   2. Click 'New administrative unit'"
            log "yellow" "   3. Name: $au_name"
            log "yellow" "   4. Description: Restricted administrative unit for tenant $tenant_code management operations"
            log "yellow" "   5. Check 'Restricted management administrative unit'"
            log "yellow" "   6. Click 'Create'"
            log "yellow" ""
            log "yellow" "   After creating the AU manually, re-run this script."
            log "yellow" ""
            exit 1
        else
            log "green" "Successfully created administrative unit: $au_name (ID: $au_id)"
        fi
    fi
    
    # Assign AU-scoped roles to current user
    if [ -n "$au_id" ] && [ "$au_id" != "null" ]; then
        log "cyan" "Assigning AU-scoped roles to current user..."
        
        local au_roles=("User Administrator" "Groups Administrator" "Privileged Authentication Administrator" "License Administrator")
        
        for role_name in "${au_roles[@]}"; do
            assign_au_scoped_role "$au_id" "$current_user_id" "$role_name"
        done
    fi
    
    echo "$au_id"
}

# Assign AU-scoped role using roleManagement API
assign_au_scoped_role() {
    local au_id=$1
    local user_id=$2
    local role_name=$3
    
    [ "$WHATIF" = true ] && { log "yellow" "WHATIF: Would assign AU-scoped role '$role_name'"; return 0; }
    
    # Map role names to their role definition IDs (universal UUIDs)
    local role_id=""
    case "$role_name" in
        "User Administrator")
            role_id="fe930be7-5e62-47db-91af-98c3a49a38b1"
            ;;
        "Groups Administrator")
            role_id="fdd7a751-b60b-444a-984c-02652fe8fa1c"
            ;;
        "Privileged Authentication Administrator")
            role_id="7be44c8a-adaf-4e2a-84d6-ab2649e08a13"
            ;;
        "License Administrator")
            role_id="4d6ac14f-3453-41d0-bef9-a3e0c569773a"
            ;;
        *)
            log "red" "Unknown AU role: $role_name"
            return 1
            ;;
    esac
    
    # Create assignment using roleManagement API
    local assignment_body
    assignment_body=$(jq -n \
        --arg roleId "$role_id" \
        --arg userId "$user_id" \
        --arg auId "$au_id" \
        '{
            "@odata.type": "#microsoft.graph.unifiedRoleAssignment",
            roleDefinitionId: $roleId,
            principalId: $userId,
            directoryScopeId: ("/administrativeUnits/" + $auId)
        }')
    
    local assignment
    assignment=$(graph_request "POST" \
        "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" \
        "Assigning AU-scoped role '$role_name'" \
        "$assignment_body" \
        "true")
    
    if echo "$assignment" | jq -e '.id' > /dev/null 2>&1; then
        log "green" "Successfully assigned AU-scoped role: $role_name"
    else
        log "yellow" "Could not assign AU-scoped role: $role_name (may already exist)"
    fi
}

# Create or verify MSP admin user
create_msp_admin_user() {
    local tenant_code=$1
    local onmicrosoft_domain=$2
    
    if [ -z "$onmicrosoft_domain" ]; then
        log "yellow" "Warning: No onmicrosoft.com domain provided, skipping MSP admin user creation"
        return 0
    fi
    
    local upn="${tenant_code}-cxnmsp-admin@${onmicrosoft_domain}"
    local display_name="${tenant_code}-cxnmsp-admin"
    
    log "cyan" ""
    log "cyan" "Checking MSP admin user: $upn"
    
    # Check if user exists
    local existing_user
    existing_user=$(graph_request "GET" \
        "https://graph.microsoft.com/v1.0/users?\$filter=userPrincipalName%20eq%20'$upn'" \
        "Checking if user '$upn' exists" \
        "" \
        "true")
    
    local user_count=$(echo "$existing_user" | jq '.value | length')
    
    if [ "$user_count" -gt 0 ]; then
        log "yellow" "MSP admin user already exists: $upn"
        return 0
    fi
    
    [ "$WHATIF" = true ] && { log "yellow" "WHATIF: Would create user '$upn'"; return 0; }
    
    # Generate random password (UUID)
    local password=$(cat /proc/sys/kernel/random/uuid)
    
    # Create user
    local user_body
    user_body=$(jq -n \
        --arg upn "$upn" \
        --arg displayName "$display_name" \
        --arg mailNickname "${tenant_code}-cxnmsp-admin" \
        --arg password "$password" \
        '{
            accountEnabled: true,
            displayName: $displayName,
            mailNickname: $mailNickname,
            userPrincipalName: $upn,
            passwordProfile: {
                forceChangePasswordNextSignIn: true,
                password: $password
            },
            usageLocation: "BE"
        }')
    
    local new_user
    new_user=$(graph_request "POST" \
        "https://graph.microsoft.com/v1.0/users" \
        "Creating user '$upn'" \
        "$user_body")
    
    if echo "$new_user" | jq -e '.id' > /dev/null 2>&1; then
        log "green" "Successfully created MSP admin user: $upn"
        log "yellow" "Initial password: $password"
        log "yellow" "IMPORTANT: Save this password securely! User must change password on first login."
    else
        log "red" "Failed to create MSP admin user"
        return 1
    fi
}

# Create Entra group
create_group() {
    local group_name=$1
    local description=$2
    local role_assignable=$3
    local admin_unit_id=$4
    
    # Check if group exists
    local existing_group
    existing_group=$(graph_request "GET" \
        "https://graph.microsoft.com/v1.0/groups?\$filter=displayName%20eq%20'$group_name'" \
        "Checking if group '$group_name' exists" \
        "" \
        "true")
    
    local group_count=$(echo "$existing_group" | jq '.value | length' 2>/dev/null || echo "0")
    
    if [ "$group_count" -gt 0 ]; then
        local group=$(echo "$existing_group" | jq '.value[0]')
        local group_id=$(echo "$group" | jq -r '.id')
        log "yellow" "Group '$group_name' already exists"
        
        # Add to AU if specified and not role-assignable
        if [ -n "$admin_unit_id" ] && [ "$admin_unit_id" != "null" ] && [ "$role_assignable" = "false" ]; then
            add_group_to_au "$group_id" "$admin_unit_id"
        fi
        
        echo "$group"
        return 0
    fi
    
    [ "$WHATIF" = true ] && { log "yellow" "WHATIF: Would create group '$group_name' (role-assignable: $role_assignable)"; echo "{}"; return 0; }
    
    # Create group
    local mail_nickname=$(echo "$group_name" | tr -cd '[:alnum:]')
    local group_body
    
    if [ "$role_assignable" = "true" ]; then
        group_body=$(jq -n \
            --arg name "$group_name" \
            --arg desc "$description" \
            --arg nick "$mail_nickname" \
            '{
                displayName: $name,
                mailNickname: $nick,
                description: $desc,
                mailEnabled: false,
                securityEnabled: true,
                isAssignableToRole: true
            }')
    else
        group_body=$(jq -n \
            --arg name "$group_name" \
            --arg desc "$description" \
            --arg nick "$mail_nickname" \
            '{
                displayName: $name,
                mailNickname: $nick,
                description: $desc,
                mailEnabled: false,
                securityEnabled: true
            }')
    fi
    
    local group
    group=$(graph_request "POST" \
        "https://graph.microsoft.com/v1.0/groups" \
        "Creating group '$group_name'" \
        "$group_body")
    
    local group_id=$(echo "$group" | jq -r '.id')
    if [ -n "$group_id" ] && [ "$group_id" != "null" ]; then
        log "green" "Successfully created group: $group_name (ID: $group_id)"
        
        # Add to AU if specified and not role-assignable
        if [ -n "$admin_unit_id" ] && [ "$admin_unit_id" != "null" ] && [ "$role_assignable" = "false" ]; then
            add_group_to_au "$group_id" "$admin_unit_id"
        fi
        
        echo "$group"
    else
        log "red" "Failed to create group: $group_name"
        echo "{}"
    fi
}

# Add group to administrative unit
add_group_to_au() {
    local group_id=$1
    local au_id=$2
    
    [ "$WHATIF" = true ] && { log "yellow" "WHATIF: Would add group to AU"; return 0; }
    
    local member_body
    member_body=$(jq -n \
        --arg gid "$group_id" \
        '{
            "@odata.id": ("https://graph.microsoft.com/v1.0/directoryObjects/" + $gid)
        }')
    
    graph_request "POST" \
        "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$au_id/members/\$ref" \
        "Adding group to administrative unit" \
        "$member_body" \
        "true" > /dev/null
    
    log "green" "Added group to administrative unit"
}

# Assign RBAC role to group
assign_rbac_role() {
    local group_id=$1
    local role_name=$2
    local group_name=$3
    local subscription_id=$4
    
    [ "$WHATIF" = true ] && { log "yellow" "WHATIF: Would assign RBAC role '$role_name' to group '$group_name'"; return 0; }
    
    # Check if assignment already exists
    local existing=$(az role assignment list \
        --assignee "$group_id" \
        --role "$role_name" \
        --scope "/subscriptions/$subscription_id" \
        --query "[0].id" \
        --output tsv 2>/dev/null || echo "")
    
    if [ -n "$existing" ]; then
        log "yellow" "RBAC role '$role_name' already assigned to group '$group_name'"
        return 0
    fi
    
    # Create assignment
    if az role assignment create \
        --assignee-object-id "$group_id" \
        --assignee-principal-type Group \
        --role "$role_name" \
        --scope "/subscriptions/$subscription_id" \
        >/dev/null 2>&1; then
        log "green" "Successfully assigned RBAC role '$role_name' to group '$group_name'"
    else
        log "red" "Failed to assign RBAC role '$role_name' to group '$group_name'"
    fi
}

# Assign tenant-level RBAC role
assign_tenant_rbac_role() {
    local group_id=$1
    local role_name=$2
    local group_name=$3
    local scope=$4
    
    [ "$WHATIF" = true ] && { log "yellow" "WHATIF: Would assign tenant RBAC role '$role_name' to group '$group_name'"; return 0; }
    
    # Check if assignment already exists
    local existing=$(az role assignment list \
        --assignee "$group_id" \
        --role "$role_name" \
        --scope "$scope" \
        --query "[0].id" \
        --output tsv 2>/dev/null || echo "")
    
    if [ -n "$existing" ]; then
        log "yellow" "Tenant RBAC role '$role_name' already assigned to group '$group_name'"
        return 0
    fi
    
    # Create assignment
    if az role assignment create \
        --assignee-object-id "$group_id" \
        --assignee-principal-type Group \
        --role "$role_name" \
        --scope "$scope" \
        >/dev/null 2>&1; then
        log "green" "Successfully assigned tenant RBAC role '$role_name' to group '$group_name'"
    else
        log "red" "Failed to assign tenant RBAC role '$role_name' to group '$group_name'"
    fi
}

# Assign Entra directory role using roleManagement API
assign_entra_role() {
    local group_id=$1
    local role_name=$2
    local group_name=$3
    
    [ "$WHATIF" = true ] && { log "yellow" "WHATIF: Would assign Entra role '$role_name' to group '$group_name'"; return 0; }
    
    # Get role definition
    local role_definition
    role_definition=$(graph_request "GET" \
        "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?\$filter=displayName%20eq%20'$role_name'" \
        "Getting role definition for '$role_name'" \
        "" \
        "true")
    
    local role_definition_id=$(echo "$role_definition" | jq -r '.value[0].id' 2>/dev/null || echo "")
    
    if [ -z "$role_definition_id" ] || [ "$role_definition_id" = "null" ]; then
        log "red" "Role '$role_name' not found"
        return 1
    fi
    
    # Check if assignment already exists
    local existing_assignment
    existing_assignment=$(graph_request "GET" \
        "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?\$filter=principalId%20eq%20'$group_id'%20and%20roleDefinitionId%20eq%20'$role_definition_id'" \
        "Checking existing role assignments" \
        "" \
        "true")
    
    local assignment_count=$(echo "$existing_assignment" | jq '.value | length' 2>/dev/null || echo "0")
    
    if [ "$assignment_count" -gt 0 ]; then
        log "yellow" "Entra role '$role_name' already assigned to group '$group_name'"
        return 0
    fi
    
    # Create role assignment
    local assignment_body
    assignment_body=$(jq -n \
        --arg roleDefId "$role_definition_id" \
        --arg principalId "$group_id" \
        '{
            "@odata.type": "#microsoft.graph.unifiedRoleAssignment",
            roleDefinitionId: $roleDefId,
            principalId: $principalId,
            directoryScopeId: "/"
        }')
    
    local assignment
    assignment=$(graph_request "POST" \
        "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" \
        "Assigning Entra role '$role_name' to group '$group_name'" \
        "$assignment_body" \
        "true")
    
    if echo "$assignment" | jq -e '.id' > /dev/null 2>&1; then
        log "green" "Successfully assigned Entra role '$role_name' to group '$group_name'"
    else
        log "red" "Failed to assign Entra role '$role_name' to group '$group_name'"
    fi
}

#
# Main execution
#

main() {
    parse_args "$@"
    
    log "cyan" "=== Complete Entra ID Setup ==="
    
    check_requirements
    
    # Determine tenant code
    if [ -z "$TENANT_CODE" ]; then
        local config_files=("$SCRIPT_DIR"/*-config.json)
        
        if [ ${#config_files[@]} -eq 1 ] && [ -f "${config_files[0]}" ]; then
            CONFIG_FILE="${config_files[0]}"
            TENANT_CODE=$(jq -r '.tenantconfig.tenantCode' "$CONFIG_FILE" 2>/dev/null || echo "")
            
            if [ -n "$TENANT_CODE" ] && [ "$TENANT_CODE" != "null" ]; then
                log "green" "Found config file: $CONFIG_FILE"
                log "green" "Using TenantCode from config: $TENANT_CODE"
            else
                log "red" "No tenantCode found in configuration. Please provide -t TENANT_CODE parameter."
                exit 1
            fi
        elif [ ${#config_files[@]} -gt 1 ]; then
            log "red" "Multiple config files found. Please specify -t TENANT_CODE parameter."
            exit 1
        else
            log "red" "No config file found and no TenantCode parameter provided."
            log "red" "Please provide -t TENANT_CODE parameter to create initial config."
            exit 1
        fi
    else
        log "green" "Using TenantCode from parameter: $TENANT_CODE"
    fi
    
    # Set config filename
    [ -z "$CONFIG_FILE" ] && CONFIG_FILE="$SCRIPT_DIR/${TENANT_CODE}-config.json"
    log "cyan" "Configuration file: $CONFIG_FILE"
    
    # Load configuration
    local config
    config=$(load_config "$CONFIG_FILE")
    
    # Get account information
    log "cyan" ""
    log "cyan" "Checking Azure CLI availability and login status..."
    
    local account_info
    account_info=$(az account show 2>/dev/null || echo "{}")
    
    if [ "$(echo "$account_info" | jq -r '.id')" = "null" ]; then
        log "red" "Error: Not logged in to Azure CLI"
        exit 1
    fi
    
    log "green" "✓ Logged in to Azure CLI"
    
    local account_name=$(echo "$account_info" | jq -r '.user.name')
    local subscription_name=$(echo "$account_info" | jq -r '.name')
    local tenant_id=$(echo "$account_info" | jq -r '.tenantId')
    local subscription_id=$(echo "$account_info" | jq -r '.id')
    local subscription_prefix=$(echo "$subscription_id" | cut -d'-' -f1)
    
    log "green" "  - Account: $account_name"
    log "green" "  - Subscription: $subscription_name"
    log "green" "  - Tenant: $tenant_id"
    log "green" "  - Subscription prefix: $subscription_prefix"
    log "green" "  - Tenant code: $TENANT_CODE"
    
    # Update configuration
    config=$(echo "$config" | jq \
        --arg tenantCode "$TENANT_CODE" \
        --arg tenantId "$tenant_id" \
        --arg subscriptionId "$subscription_id" \
        '.tenantconfig.tenantCode = $tenantCode |
         .tenantconfig.tenantId = $tenantId |
         .subscriptionId = $subscriptionId')
    
    log "green" "Updated configuration with current subscription info"
    
    # Get current user
    local current_user
    current_user=$(get_current_user)
    local current_user_id=$(echo "$current_user" | jq -r '.id')
    
    if [ -z "$current_user_id" ] || [ "$current_user_id" = "null" ]; then
        log "red" "Cannot proceed without current user information"
        exit 1
    fi
    
    # Get onmicrosoft.com domain
    local onmicrosoft_domain
    onmicrosoft_domain=$(get_onmicrosoft_domain) || onmicrosoft_domain=""
    
    if [ -n "$onmicrosoft_domain" ]; then
        config=$(echo "$config" | jq --arg domain "$onmicrosoft_domain" '.tenantconfig.onMicrosoftDomain = $domain')
    else
        onmicrosoft_domain=$(echo "$config" | jq -r '.tenantconfig.onMicrosoftDomain // empty')
        [ -n "$onmicrosoft_domain" ] && log "yellow" "Using onmicrosoft.com domain from config: $onmicrosoft_domain"
    fi
    
    # Setup Administrative Unit
    local restricted_au_id
    restricted_au_id=$(setup_restricted_au "$current_user_id" "$TENANT_CODE")
    
    if [ -n "$restricted_au_id" ] && [ "$restricted_au_id" != "null" ]; then
        config=$(echo "$config" | jq --arg auid "$restricted_au_id" '.tenantconfig.restrictedAdminUnitId = $auid')
    fi
    
    # Create MSP admin user
    create_msp_admin_user "$TENANT_CODE" "$onmicrosoft_domain"
    
    # Create tenant-level groups
    log "cyan" ""
    log "cyan" "=== Creating Tenant Groups ==="
    
    local tenant_groups_config="{}"
    local group_count=$(echo "$TENANT_GROUPS" | jq 'length')
    
    for ((i=0; i<group_count; i++)); do
        local group=$(echo "$TENANT_GROUPS" | jq -r ".[$i]")
        local name=$(echo "$group" | jq -r '.name')
        local description=$(echo "$group" | jq -r '.description')
        local roles_count=$(echo "$group" | jq '.roles | length')
        
        # Generate full group name: sec-tenant-{tenantcode}-{basename}
        local full_name="sec-tenant-$TENANT_CODE-$name"
        
        # Check if group needs Entra directory roles (role-assignable)
        local has_roles=false
        [ "$roles_count" -gt 0 ] && has_roles=true
        
        # Create group (role-assignable groups are NOT added to AU)
        local group_obj
        if [ "$has_roles" = true ]; then
            log "yellow" "Creating role-assignable group (NOT in AU): $full_name"
            group_obj=$(create_group "$full_name" "$description" true "")
        else
            log "cyan" "Creating non-role-assignable group (IN AU): $full_name"
            group_obj=$(create_group "$full_name" "$description" false "$restricted_au_id")
        fi
        
        if [ -n "$group_obj" ] && [ "$group_obj" != "null" ]; then
            local group_id=$(echo "$group_obj" | jq -r '.id')
            tenant_groups_config=$(echo "$tenant_groups_config" | jq \
                --arg name "$name" \
                --arg id "$group_id" \
                '.[$name] = $id')
        fi
    done
    
    # Update config with tenant groups and prefix
    config=$(echo "$config" | jq \
        --arg prefix "sec-tenant-$TENANT_CODE" \
        --argjson groups "$tenant_groups_config" \
        '.tenantconfig.prefix = $prefix | .tenantconfig.groups = $groups')
    
    # Create subscription-level groups if not Entra-only mode
    if [ "$SETUP_ENTRA_ONLY" = false ]; then
        log "cyan" ""
        log "cyan" "=== Creating Subscription Groups ==="
        
        local sub_groups_config="{}"
        local sub_group_count=$(echo "$SUBSCRIPTION_GROUPS" | jq 'length')
        
        for ((i=0; i<sub_group_count; i++)); do
            local group=$(echo "$SUBSCRIPTION_GROUPS" | jq -r ".[$i]")
            local name=$(echo "$group" | jq -r '.name')
            local description=$(echo "$group" | jq -r '.description')
            
            # Generate full group name: sec-az-{tenantcode}-{subprefix}-{basename}
            local full_name="sec-az-$TENANT_CODE-$subscription_prefix-$name"
            
            # All subscription groups go IN the AU
            local group_obj
            group_obj=$(create_group "$full_name" "$description" false "$restricted_au_id")
            
            if [ -n "$group_obj" ] && [ "$group_obj" != "null" ]; then
                local group_id=$(echo "$group_obj" | jq -r '.id')
                sub_groups_config=$(echo "$sub_groups_config" | jq \
                    --arg name "$name" \
                    --arg id "$group_id" \
                    '.[$name] = $id')
            fi
        done
        
        # Update config with subscription groups
        config=$(echo "$config" | jq \
            --arg subId "$subscription_id" \
            --arg prefix "sec-az-$TENANT_CODE-$subscription_prefix" \
            --argjson groups "$sub_groups_config" \
            '.subscriptions[$subId].prefix = $prefix | .subscriptions[$subId].groups = $groups')
        
        # Wait for Azure AD replication
        log "yellow" ""
        log "yellow" "Waiting 15 seconds for Azure AD replication before role assignments..."
        sleep 15
        
        # Assign subscription RBAC roles
        log "cyan" ""
        log "cyan" "=== Assigning Subscription RBAC Roles ==="
        
        for ((i=0; i<sub_group_count; i++)); do
            local group=$(echo "$SUBSCRIPTION_GROUPS" | jq -r ".[$i]")
            local name=$(echo "$group" | jq -r '.name')
            local group_id=$(echo "$sub_groups_config" | jq -r --arg name "$name" '.[$name]')
            local rbac_roles=$(echo "$group" | jq -r '.rbacRoles[]' 2>/dev/null || echo "")
            
            if [ -n "$group_id" ] && [ "$group_id" != "null" ] && [ -n "$rbac_roles" ]; then
                local full_name="sec-az-$TENANT_CODE-$subscription_prefix-$name"
                while IFS= read -r role; do
                    [ -n "$role" ] && assign_rbac_role "$group_id" "$role" "$full_name" "$subscription_id"
                done <<< "$rbac_roles"
            fi
        done
        
        # Assign Entra directory roles to tenant groups
        log "cyan" ""
        log "cyan" "=== Assigning Entra Directory Roles ==="
        
        for ((i=0; i<group_count; i++)); do
            local group=$(echo "$TENANT_GROUPS" | jq -r ".[$i]")
            local name=$(echo "$group" | jq -r '.name')
            local full_name="sec-tenant-$TENANT_CODE-$name"
            local group_id=$(echo "$tenant_groups_config" | jq -r --arg name "$name" '.[$name]')
            local dir_roles=$(echo "$group" | jq -r '.roles[]' 2>/dev/null || echo "")
            
            if [ -n "$group_id" ] && [ "$group_id" != "null" ] && [ -n "$dir_roles" ]; then
                while IFS= read -r role; do
                    [ -n "$role" ] && assign_entra_role "$group_id" "$role" "$full_name"
                done <<< "$dir_roles"
            fi
        done
        
        # Assign tenant-level RBAC roles for reservations
        log "cyan" ""
        log "cyan" "=== Assigning Tenant-level RBAC Roles (Reservations) ==="
        
        local reservations_scope="/providers/Microsoft.Capacity"
        
        # Reservations Reader
        local res_read_name="reservations-read"
        local res_read_id=$(echo "$tenant_groups_config" | jq -r --arg name "$res_read_name" '.[$name]')
        [ -n "$res_read_id" ] && [ "$res_read_id" != "null" ] && \
            assign_tenant_rbac_role "$res_read_id" "Reservations Reader" "sec-tenant-$TENANT_CODE-$res_read_name" "$reservations_scope"
        
        # Reservations Admin
        local res_admin_name="reservations-admin"
        local res_admin_id=$(echo "$tenant_groups_config" | jq -r --arg name "$res_admin_name" '.[$name]')
        [ -n "$res_admin_id" ] && [ "$res_admin_id" != "null" ] && \
            assign_tenant_rbac_role "$res_admin_id" "Reservations Administrator" "sec-tenant-$TENANT_CODE-$res_admin_name" "$reservations_scope"
        
        # Reservations Purchaser
        local res_purch_name="reservations-purchase"
        local res_purch_id=$(echo "$tenant_groups_config" | jq -r --arg name "$res_purch_name" '.[$name]')
        [ -n "$res_purch_id" ] && [ "$res_purch_id" != "null" ] && \
            assign_tenant_rbac_role "$res_purch_id" "Reservation Purchaser" "sec-tenant-$TENANT_CODE-$res_purch_name" "$reservations_scope"
    fi
    
    # Save final configuration
    local final_config
    final_config=$(echo "$config" | jq \
        --arg lastUpdated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.tenantconfig.lastUpdated = $lastUpdated')
    
    save_config "$CONFIG_FILE" "$final_config"
    
    log "green" ""
    log "green" "=== Complete Entra ID Setup Finished ==="
    log "cyan" "Summary:"
    log "green" "✓ Configuration file: $CONFIG_FILE"
    log "green" "✓ Tenant code: $TENANT_CODE"
    [ -n "$onmicrosoft_domain" ] && log "green" "✓ OnMicrosoft domain: $onmicrosoft_domain"
    [ -n "$restricted_au_id" ] && log "green" "✓ Restricted AU: $restricted_au_id"
    
    log "cyan" ""
    log "cyan" "To verify the created groups, run:"
    log "white" "az ad group list --output table"
}

# Run main function with all arguments
main "$@"
