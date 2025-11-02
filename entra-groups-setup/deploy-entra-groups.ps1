#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete Entra ID setup: Groups, Administrative Unit, and Role Assignments
.DESCRIPTION
    This unified script creates all required Entra groups, sets up administrative unit,
    and assigns both Entra directory roles and RBAC roles. All groups are hard-coded 
    for standalone usage (copy/paste or Invoke-WebRequest).
.PARAMETER ConfigFile
    Path to the JSON configuration file (default: config.json)
.PARAMETER TenantCode
    Tenant code to use for group naming (optional, will be derived if not provided)
.PARAMETER SetupEntraOnly
    Only setup Entra ID administrative unit and roles, skip group creation
.PARAMETER SuperAdmins
    Comma-separated list of user principal names to add to groups with include-super-admin flag
    Example: -SuperAdmins "user1@domain.com,user2@domain.com"
.PARAMETER AllSubscriptions
    Process subscription-level groups for all subscriptions in the current tenant.
    When set, the script will:
    - Query all subscriptions using 'az account list'
    - Filter by homeTenantId matching the current tenant
    - Create subscription-level groups for each subscription with appropriate prefix
    - Save all subscriptions to the configuration file
    If not set, only the active subscription is processed (default behavior).
.PARAMETER EntraOnly
    Only process Entra ID tenant-level groups. Skip all subscription-level groups.
.PARAMETER SubscriptionsOnly
    Only process subscription-level groups. Skip all Entra ID tenant-level groups.
.NOTES
    Requires: Global Admin and Subscription Owner permissions
    Requires: Azure CLI (az) installed and logged in
    Author: Generated for Lub-LZ
#>

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [string]$ConfigFile,
    [string]$TenantCode,
    [switch]$SetupEntraOnly,
    [switch]$ShowPassword,
    [string]$SuperAdmins,
    [switch]$AllSubscriptions,
    [switch]$EntraOnly,
    [switch]$SubscriptionsOnly
)

# Hard-coded group definitions for standalone usage (names without sec-tenant- prefix)
$aTenantGroups = @(
    @{"name"="dailyadmin";
    "description"="group for daily operations";
    "roles"=@("User Administrator","Groups Administrator")},
    @{"name"="elevadmin";
    "description"="group with elevated roles";
     "include-super-admin" = $true;
    "roles"=@("User Administrator","Groups Administrator","Security Administrator","Application Administrator","Global Reader","License Administrator","Authentication Administrator","Authentication Policy Administrator", "Privileged Authentication Administrator","Conditional Access Administrator")},
    @{"name"="dailyadmin";
    "description"="group for daily operations";
    "roles"=@("User Administrator","Groups Administrator")},
    @{"name"="sharepoint-admin";
    "description"="group for SharePoint administration";
    "include-super-admin" = $true;
    "roles"=@("SharePoint Administrator")},
    @{"name"="intune-admin";
    "include-super-admin" = $true;
    "description"="group for Intune administration";
    "roles"=@("Intune Administrator")},
    @{"name"="teams-admin";
    "include-super-admin" = $true;
    "description"="group for Teams administration";
    "roles"=@("Teams Administrator")},
    @{"name"="privileged-role-admin";
    "description"="group for Privileged Role administration";
    "include-super-admin" = $true;
    "roles"=@("Privileged Role Administrator")},
    @{"name"="reservations-read";
    "description"="can read azure reservations";
    "roles"=@()},
    @{"name"="reservations-admin";
    "description"="can manage azure reservations";
    "roles"=@()},
    @{"name"="reservations-purchase";
    "description"="can purchase azure reservations";
    "roles"=@()},
    @{"name"="break-glass";
    "description"="break glass accounts, dynamic, informational";
    "roles"=@()},
    @{"name"="super-admin";
    "super-admin"=$true;
    "description"="Members of this group can be made eligible for high level roles, in case of P2 license availability";
    "roles"=@()}
)

$aSubscriptionGroups = @(
    @{"name"="reader";
    "description"="Reader on subscription";
    "RBACroles"=@("Reader")},
    @{"name"="dailyadmin";
    "description"="Daily admin on subscription";
    "RBACroles"=@("Reader","Backup Reader","Desktop Virtualization Session Host Operator","Desktop Virtualization User Session Operator","Desktop Virtualization Power On Off Contributor")},
   @{"name"="dnsadmin";
    "description"="DNS Contributor on subscription";
    "RBACroles"=@("DNS Zone Contributor")},
    @{"name"="contributor";
    "description"="Contributor on subscription";
    "RBACroles"=@("Contributor")},
    @{"name"="costreader";
    "description"="can read cost information";
    "RBACroles"=@("Cost Management Reader")},
    @{"name"="sec-uaa";
    "description"="Restricted User Access Administrator";
    "include-super-admin" = $true;
    "RBACroles"=@("User Access Administrator")},
    @{"name"="owner";
    "description"="Owner on subscription";
    "RBACroles"=@("Owner")}
)

# Helper function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    switch ($Color) {
        "Green" { Write-Host $Message -ForegroundColor Green }
        "Yellow" { Write-Host $Message -ForegroundColor Yellow }
        "Red" { Write-Host $Message -ForegroundColor Red }
        "Cyan" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

# Function to load configuration
function Get-Configuration {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-ColorOutput "Configuration file not found: $Path" "Yellow"
        return $null
    }
    
    try {
        $config = Get-Content $Path | ConvertFrom-Json
        return $config
    }
    catch {
        Write-ColorOutput "Error loading configuration file: $($_.Exception.Message)" "Red"
        return $null
    }
}

# Function to save configuration
function Save-ConfigurationFile {
    param(
        [string]$Path,
        [object]$Config,
        [hashtable]$ProcessedTenantGroups = @{},
        [hashtable]$ProcessedSubscriptionGroups = @{},
        [string]$SubscriptionPrefix = "",
        [array]$AllSubscriptionPrefixes = @()
    )
    
    try {
        # Load existing config to preserve other subscriptions
        $existingSubscriptions = @{}
        if (Test-Path $Path) {
            try {
                $existingConfig = Get-Content $Path | ConvertFrom-Json
                if ($existingConfig.subscriptions) {
                    # Convert existing subscriptions to hashtable
                    foreach ($prop in $existingConfig.subscriptions.PSObject.Properties) {
                        $existingSubscriptions[$prop.Name] = @{
                            prefix = $prop.Value.prefix
                            groups = @{}
                        }
                        # Copy groups
                        foreach ($groupProp in $prop.Value.groups.PSObject.Properties) {
                            $existingSubscriptions[$prop.Name].groups[$groupProp.Name] = $groupProp.Value
                        }
                    }
                }
            }
            catch {
                Write-ColorOutput "Warning: Could not load existing subscriptions, starting fresh" "Yellow"
            }
        }
        
        # New structure: tenantconfig and subscriptions hashtable
        $configHash = @{
            tenantconfig = @{
                tenantCode = $Config.tenantCode
                tenantId = $Config.tenantId
                onMicrosoftDomain = $Config.onMicrosoftDomain
                restrictedAdminUnitId = $Config.restrictedAdminUnitId
                prefix = "sec-tenant-$($Config.tenantCode)"
                groups = @{}  # Flat structure: "groupname" = "guid"
                lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            }
            subscriptions = $existingSubscriptions  # Start with existing subscriptions
        }
        
        # Add processed tenant groups (store base name without prefix, like subscription groups)
        foreach ($groupName in $ProcessedTenantGroups.Keys) {
            # Remove the "sec-tenant-{tenantcode}-" prefix to get base name
            $cleanGroupName = $groupName -replace "^sec-tenant-$($Config.tenantCode)-", ""
            $configHash.tenantconfig.groups[$cleanGroupName] = $ProcessedTenantGroups[$groupName]
        }
        
        # Handle multiple subscriptions if AllSubscriptionPrefixes is provided
        if ($AllSubscriptionPrefixes.Count -gt 0) {
            # Process groups from all subscriptions
            foreach ($subInfo in $AllSubscriptionPrefixes) {
                $subId = $subInfo.id
                $subPrefix = $subInfo.prefix
                
                # Initialize subscription entry
                $configHash.subscriptions[$subId] = @{
                    prefix = "sec-az-$($Config.tenantCode)-$subPrefix"
                    groups = @{}
                }
                
                # Find and add groups for this subscription prefix
                foreach ($fullGroupName in $ProcessedSubscriptionGroups.Keys) {
                    if ($fullGroupName -match "^sec-az-$($Config.tenantCode)-$subPrefix-(.+)$") {
                        $cleanGroupName = $Matches[1]
                        $configHash.subscriptions[$subId].groups[$cleanGroupName] = $ProcessedSubscriptionGroups[$fullGroupName]
                    }
                }
            }
        }
        # Single subscription mode
        elseif ($Config.subscriptionId) {
            $configHash.subscriptions[$Config.subscriptionId] = @{
                prefix = "sec-az-$($Config.tenantCode)-$SubscriptionPrefix"
                groups = @{}
            }
            
            # Add processed subscription groups (without prefix in name)
            foreach ($fullGroupName in $ProcessedSubscriptionGroups.Keys) {
                # Remove the "sec-az-{tenantcode}-xxxx-" prefix from group name
                $cleanGroupName = $fullGroupName -replace "^sec-az-$($Config.tenantCode)-$SubscriptionPrefix-", ""
                $configHash.subscriptions[$Config.subscriptionId].groups[$cleanGroupName] = $ProcessedSubscriptionGroups[$fullGroupName]
            }
        }
        
        $configHash | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
        Write-ColorOutput "Configuration saved to: $Path" "Green"
    }
    catch {
        Write-ColorOutput "Error saving configuration: $($_.Exception.Message)" "Red"
    }
}

# Function to get the onmicrosoft.com domain name
function Get-OnMicrosoftDomain {
    try {
        $domains = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/domains" -Description "Getting tenant domains" -IgnoreError
        
        if ($domains -and $domains.value) {
            $onMicrosoftDomain = $domains.value | Where-Object { $_.id -like "*.onmicrosoft.com" -and $_.isInitial -eq $true } | Select-Object -First 1
            
            if ($onMicrosoftDomain) {
                return $onMicrosoftDomain.id
            }
        }
        
        Write-ColorOutput "Warning: Could not find onmicrosoft.com domain" "Yellow"
        return $null
    }
    catch {
        Write-ColorOutput "Error getting onmicrosoft.com domain: $($_.Exception.Message)" "Yellow"
        return $null
    }
}

# Function to execute Microsoft Graph REST API call
function Invoke-GraphRequest {
    param(
        [string]$Method = "GET",
        [string]$Uri,
        [object]$Body = $null,
        [string]$Description,
        [switch]$IgnoreError
    )
    
    Write-ColorOutput "Executing: $Description" "Cyan"
    
    if ($WhatIf) {
        Write-ColorOutput "WHATIF: Would execute: $Method $Uri" "Yellow"
        if ($Body) {
            Write-ColorOutput "WHATIF: With body: $($Body | ConvertTo-Json -Compress)" "Yellow"
        }
        return $null
    }
    
    try {
        $azArgs = @("rest", "--method", $Method, "--url", $Uri)
        
        # Add Content-Type header for POST, PUT, PATCH requests
        if ($Method -in @("POST", "PUT", "PATCH")) {
            # Use explicit header format that works on both Windows and Linux
            $azArgs += "--headers"
            $azArgs += "Content-Type=application/json"
        }
        
        if ($Body) {
            $bodyJson = $Body | ConvertTo-Json -Depth 10 -Compress
            
            # Windows PowerShell has issues with JSON in --body parameter
            # Use temporary file approach for cross-platform compatibility
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                $bodyJson | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline
                $azArgs += "--body"
                $azArgs += "@$tempFile"
                
                $result = & az @azArgs 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            $result = & az @azArgs 2>&1
            $exitCode = $LASTEXITCODE
        }
        
        if ($exitCode -ne 0 -and -not $IgnoreError) {
            Write-ColorOutput "Error executing Graph request: $result" "Red"
            return $null
        }
        
        if ($result -and $result -ne "null") {
            return $result | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        return $result
    }
    catch {
        if (-not $IgnoreError) {
            Write-ColorOutput "Exception executing Graph request: $($_.Exception.Message)" "Red"
        }
        return $null
    }
}

# Function to check if group exists
function Get-GroupByName {
    param([string]$GroupName)
    
    $existingGroup = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$GroupName'" -Description "Checking if group '$GroupName' exists" -IgnoreError
    
    if ($existingGroup -and $existingGroup.value -and $existingGroup.value.Count -gt 0) {
        return $existingGroup.value[0]
    }
    return $null
}

# Function to create Entra group with Microsoft Graph
function New-GraphGroup {
    param(
        [string]$GroupName,
        [string]$Description,
        [switch]$RoleAssignable,
        [string]$AdminUnitId = $null
    )
    
    $existingGroup = Get-GroupByName -GroupName $GroupName
    if ($existingGroup) {
        Write-ColorOutput "Group '$GroupName' already exists" "Yellow"
        
        # Add existing group to administrative unit if specified
        if ($AdminUnitId -and $existingGroup.id) {
            $memberBody = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($existingGroup.id)"
            }
            $addToUnit = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$AdminUnitId/members/`$ref" -Body $memberBody -Description "Adding existing group to administrative unit" -IgnoreError
            
            if ($addToUnit) {
                Write-ColorOutput "Added existing group to administrative unit" "Green"
            }
        }
        
        return $existingGroup
    }
    
    if ($WhatIf) {
        Write-ColorOutput "WHATIF: Would create group '$GroupName' (role-assignable: $RoleAssignable)" "Cyan"
        return $null
    }
    
    try {
        Write-ColorOutput "Creating group: $GroupName (role-assignable: $RoleAssignable)" "Green"
        $mailNickname = $GroupName -replace '[^a-zA-Z0-9]', ''
        
        $groupBody = @{
            displayName = $GroupName
            mailNickname = $mailNickname
            description = $Description
            mailEnabled = $false
            securityEnabled = $true
        }
        
        if ($RoleAssignable) {
            $groupBody.isAssignableToRole = $true
        }
        
        $group = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/groups" -Body $groupBody -Description "Creating group '$GroupName'"
        
        if ($group -and $group.id) {
            Write-ColorOutput "Successfully created group: $($group.displayName) (ID: $($group.id))" "Green"
            
            # Add to administrative unit if specified
            if ($AdminUnitId -and $group.id) {
                $memberBody = @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($group.id)"
                }
                $addToUnit = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$AdminUnitId/members/`$ref" -Body $memberBody -Description "Adding group to administrative unit" -IgnoreError
                
                if ($addToUnit) {
                    Write-ColorOutput "Added group to administrative unit" "Green"
                }
            }
            
            return $group
        } else {
            Write-ColorOutput "Failed to create group: $GroupName" "Red"
            return $null
        }
    }
    catch {
        Write-ColorOutput "Error creating group '$GroupName': $($_.Exception.Message)" "Red"
        return $null
    }
}

# Function to set RBAC role assignment
function Set-AzRoleAssignment {
    param(
        [string]$GroupObjectId,
        [string]$RoleName,
        [string]$GroupName,
        [string]$SubscriptionId
    )
    
    try {
        if ($WhatIf) {
            Write-ColorOutput "WHATIF: Would assign RBAC role '$RoleName' to group '$GroupName'" "Yellow"
            return
        }
        
        # Check if assignment already exists
        $existingAssignment = az role assignment list --assignee $GroupObjectId --role $RoleName --scope "/subscriptions/$SubscriptionId" --query "[0].id" --output tsv 2>&1
        
        if ($existingAssignment -and -not $existingAssignment.StartsWith("ERROR")) {
            Write-ColorOutput "RBAC role '$RoleName' already assigned to group '$GroupName' on subscription" "Yellow"
            return
        }
        
        # Create the assignment with principalType to handle replication delay
        $assignment = az role assignment create --assignee-object-id $GroupObjectId --assignee-principal-type Group --role $RoleName --scope "/subscriptions/$SubscriptionId" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Successfully assigned RBAC role '$RoleName' to group '$GroupName' on subscription" "Green"
        } else {
            Write-ColorOutput "Failed to assign RBAC role '$RoleName' to group '$GroupName': $assignment" "Red"
        }
    }
    catch {
        Write-ColorOutput "Error assigning RBAC role '$RoleName' to group '$GroupName': $($_.Exception.Message)" "Red"
    }
}

# Function to assign tenant-level RBAC role (for reservations, etc.)
function Set-TenantRbacRole {
    param(
        [string]$GroupName,
        [string]$RoleName,
        [string]$Scope
    )
    
    try {
        if ($WhatIf) {
            Write-ColorOutput "WHATIF: Would assign tenant RBAC role '$RoleName' to group '$GroupName' at scope '$Scope'" "Yellow"
            return
        }
        
        # First, verify the group exists by looking it up
        Write-ColorOutput "Verifying group '$GroupName' exists..." "Cyan"
        $group = Get-GroupByName -GroupName $GroupName
        
        if (-not $group -or -not $group.id) {
            Write-ColorOutput "Group '$GroupName' does not exist. Cannot assign role." "Red"
            return $false
        }
        
        Write-ColorOutput "Group verified: $GroupName (ID: $($group.id))" "Green"
        
        # Check if assignment already exists
        $existingAssignment = az role assignment list --assignee $group.id --role $RoleName --scope $Scope --query "[0].id" --output tsv 2>&1
        
        if ($existingAssignment -and -not $existingAssignment.StartsWith("ERROR")) {
            Write-ColorOutput "Tenant RBAC role '$RoleName' already assigned to group '$GroupName' at scope '$Scope'" "Yellow"
            return $true
        }
        
        # Create the assignment with principalType
        Write-ColorOutput "Assigning tenant RBAC role '$RoleName' to group '$GroupName' at scope '$Scope'..." "Cyan"
        $assignment = az role assignment create --assignee-object-id $group.id --assignee-principal-type Group --role $RoleName --scope $Scope 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Successfully assigned tenant RBAC role '$RoleName' to group '$GroupName' at scope '$Scope'" "Green"
            return $true
        } else {
            Write-ColorOutput "Failed to assign tenant RBAC role '$RoleName' to group '$GroupName': $assignment" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Error assigning tenant RBAC role '$RoleName' to group '$GroupName': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to get current user
function Get-CurrentUser {
    try {
        $currentUser = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/me" -Description "Getting current user" -IgnoreError
        if ($currentUser) {
            Write-ColorOutput "Current user: $($currentUser.displayName) ($($currentUser.userPrincipalName))" "Green"
            return $currentUser
        }
        return $null
    }
    catch {
        Write-ColorOutput "Error getting current user: $($_.Exception.Message)" "Red"
        return $null
    }
}

# Function to create or find Administrative Unit
function Set-RestrictedAdminUnit {
    param(
        [string]$TenantCode
    )
    
    $adminUnitName = "$TenantCode-tenant-admin"
    Write-ColorOutput "Looking for administrative unit '$adminUnitName'..." "Cyan"
    
    $adminUnits = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits" -Description "Getting administrative units" -IgnoreError
    
    $restrictedUnit = $null
    if ($adminUnits -and $adminUnits.value) {
        $restrictedUnit = $adminUnits.value | Where-Object { $_.displayName -eq $adminUnitName }
    }
    
    if ($restrictedUnit) {
        Write-ColorOutput "Found existing administrative unit: $($restrictedUnit.displayName)" "Green"
        $restrictedAdminUnitId = $restrictedUnit.id
    } else {
        Write-ColorOutput "Creating new administrative unit: $adminUnitName" "Cyan"
        
        if ($WhatIf) {
            Write-ColorOutput "WHATIF: Would create administrative unit '$adminUnitName'" "Yellow"
            return "whatif-admin-unit-id"
        }
        
        $adminUnitBody = @{
            displayName = $adminUnitName
            description = "Restricted administrative unit for tenant $TenantCode management operations"
            visibility = "HiddenMembership"
            isMemberManagementRestricted = $true
        }
        
        $newAdminUnit = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits" -Body $adminUnitBody -Description "Creating administrative unit '$adminUnitName'"
        
        if (-not $newAdminUnit -or -not $newAdminUnit.id) {
            Write-ColorOutput "Failed to create administrative unit" "Red"
            return $null
        }
        
        $restrictedAdminUnitId = $newAdminUnit.id
        Write-ColorOutput "Created administrative unit: $($newAdminUnit.displayName) (ID: $restrictedAdminUnitId)" "Green"
    }
    
    return $restrictedAdminUnitId
}

# Function to assign Entra directory role to group
function Set-EntraDirectoryRole {
    param(
        [string]$GroupId,
        [string]$RoleDisplayName,
        [string]$GroupDisplayName
    )
    
    try {
        if ($WhatIf) {
            Write-ColorOutput "WHATIF: Would assign Entra role '$RoleDisplayName' to group '$GroupDisplayName'" "Yellow"
            return
        }
        
        # Get role definition
        $roleDefinitions = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$filter=displayName eq '$RoleDisplayName'" -Description "Getting role definition for '$RoleDisplayName'" -IgnoreError
        
        if (-not $roleDefinitions -or -not $roleDefinitions.value -or $roleDefinitions.value.Count -eq 0) {
            Write-ColorOutput "Role '$RoleDisplayName' not found" "Red"
            return
        }
        
        $roleDefinitionId = $roleDefinitions.value[0].id
        
        # Check if assignment already exists
        $existingAssignments = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$GroupId' and roleDefinitionId eq '$roleDefinitionId'" -Description "Checking existing role assignments" -IgnoreError
        
        if ($existingAssignments -and $existingAssignments.value -and $existingAssignments.value.Count -gt 0) {
            Write-ColorOutput "Entra role '$RoleDisplayName' already assigned to group '$GroupDisplayName'" "Yellow"
            return
        }
        
        # Create role assignment
        $roleAssignmentBody = @{
            "@odata.type" = "#microsoft.graph.unifiedRoleAssignment"
            roleDefinitionId = $roleDefinitionId
            principalId = $GroupId
            directoryScopeId = "/"
        }
        
        $roleAssignment = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" -Body $roleAssignmentBody -Description "Assigning Entra role '$RoleDisplayName' to group '$GroupDisplayName'"
        
        if ($roleAssignment) {
            Write-ColorOutput "Successfully assigned Entra role '$RoleDisplayName' to group '$GroupDisplayName'" "Green"
        } else {
            Write-ColorOutput "Failed to assign Entra role '$RoleDisplayName' to group '$GroupDisplayName'" "Red"
        }
    }
    catch {
        Write-ColorOutput "Error assigning Entra role '$RoleDisplayName' to group '$GroupDisplayName': $($_.Exception.Message)" "Red"
    }
}

# Function to update group administrative unit membership
function Update-GroupAdminUnit {
    param(
        [string]$GroupId,
        [string]$GroupDisplayName,
        [string]$AdminUnitId
    )
    
    if (-not $AdminUnitId -or $WhatIf) {
        return
    }
    
    try {
        $memberBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$GroupId"
        }
        $addToUnit = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$AdminUnitId/members/`$ref" -Body $memberBody -Description "Adding group '$GroupDisplayName' to administrative unit" -IgnoreError
        
        if ($addToUnit) {
            Write-ColorOutput "Added group '$GroupDisplayName' to administrative unit" "Green"
        }
    }
    catch {
        Write-ColorOutput "Error adding group '$GroupDisplayName' to administrative unit: $($_.Exception.Message)" "Red"
    }
}

# Function to add a group as member of another group
function Add-GroupMember {
    param(
        [string]$GroupId,
        [string]$MemberGroupId,
        [string]$GroupName,
        [string]$MemberGroupName
    )
    
    if ($WhatIf) {
        Write-ColorOutput "WHATIF: Would add group '$MemberGroupName' as member of group '$GroupName'" "Yellow"
        return $true
    }
    
    try {
        # Check if member already exists
        $existingMembers = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members?`$filter=id eq '$MemberGroupId'" -Description "Checking if group '$MemberGroupName' is already member of '$GroupName'" -IgnoreError
        
        if ($existingMembers -and $existingMembers.value -and $existingMembers.value.Count -gt 0) {
            Write-ColorOutput "Group '$MemberGroupName' is already a member of '$GroupName'" "Yellow"
            return $true
        }
        
        # Add member
        $memberBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$MemberGroupId"
        }
        $addMember = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members/`$ref" -Body $memberBody -Description "Adding group '$MemberGroupName' as member of '$GroupName'" -IgnoreError
        
        if ($null -ne $addMember -or $LASTEXITCODE -eq 0) {
            Write-ColorOutput "Successfully added group '$MemberGroupName' as member of '$GroupName'" "Green"
            return $true
        } else {
            Write-ColorOutput "Failed to add group '$MemberGroupName' as member of '$GroupName'" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Error adding group '$MemberGroupName' as member of '$GroupName': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to assign AU-scoped roles to a group
function Add-GroupToAdminUnitWithRoles {
    param(
        [string]$GroupId,
        [string]$GroupName,
        [string]$AdminUnitId
    )
    
    if (-not $GroupId -or -not $AdminUnitId) {
        Write-ColorOutput "Warning: Cannot assign AU roles to group - missing GroupId or AdminUnitId" "Yellow"
        return $false
    }
    
    Write-ColorOutput "`nAssigning AU-scoped roles to group '$GroupName'..." "Cyan"
    
    if ($WhatIf) {
        Write-ColorOutput "WHATIF: Would assign User Administrator and Groups Administrator roles to group (AU-scoped)" "Yellow"
        return $true
    }
    
    # Define roles to assign (scoped to AU)
    $rolesToAssign = @{
        "User Administrator" = "fe930be7-5e62-47db-91af-98c3a49a38b1"
        "Groups Administrator" = "fdd7a751-b60b-444a-984c-02652fe8fa1c"
    }
    
    # Assign each role to the group (scoped to AU)
    foreach ($roleName in $rolesToAssign.Keys) {
        $roleId = $rolesToAssign[$roleName]
        
        # Check if assignment already exists
        $existingAssignments = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$GroupId' and roleDefinitionId eq '$roleId' and directoryScopeId eq '/administrativeUnits/$AdminUnitId'" -Description "Checking existing role assignments for $roleName" -IgnoreError
        
        if ($existingAssignments -and $existingAssignments.value -and $existingAssignments.value.Count -gt 0) {
            Write-ColorOutput "Role '$roleName' already assigned to group '$GroupName' (AU-scoped)" "Yellow"
            continue
        }
        
        $roleAssignmentBody = @{
            "@odata.type" = "#microsoft.graph.unifiedRoleAssignment"
            roleDefinitionId = $roleId
            principalId = $GroupId
            directoryScopeId = "/administrativeUnits/$AdminUnitId"
        }
        
        $roleAssignment = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" -Body $roleAssignmentBody -Description "Assigning $roleName role to group '$GroupName' in AU" -IgnoreError
        
        if ($roleAssignment) {
            Write-ColorOutput "✓ Assigned $roleName role to group '$GroupName' (AU-scoped)" "Green"
        }
    }
    
    return $true
}

# Function to create or verify MSP admin user
function New-MspAdminUser {
    param(
        [string]$TenantCode,
        [string]$OnMicrosoftDomain
    )
    
    if (-not $OnMicrosoftDomain) {
        Write-ColorOutput "Warning: No onmicrosoft.com domain provided, skipping MSP admin user creation" "Yellow"
        return $null
    }
    
    $userPrincipalName = "$TenantCode-cxnmsp-admin@$OnMicrosoftDomain"
    $displayName = "$TenantCode-cxnmsp-admin"
    
    Write-ColorOutput "`nChecking MSP admin user: $userPrincipalName" "Cyan"
    
    # Check if user exists
    $existingUser = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/users?`$filter=userPrincipalName eq '$userPrincipalName'" -Description "Checking if user '$userPrincipalName' exists" -IgnoreError
    
    if ($existingUser -and $existingUser.value -and $existingUser.value.Count -gt 0) {
        Write-ColorOutput "MSP admin user already exists: $userPrincipalName" "Green"
        # Return existing user without password
        return @{
            user = $existingUser.value[0]
            password = $null
            isNew = $false
        }
    }
    
    if ($WhatIf) {
        Write-ColorOutput "WHATIF: Would create user '$userPrincipalName'" "Yellow"
        return $null
    }
    
    # Generate complex random password: 16 characters with uppercase, lowercase, digits, and special chars
    $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lowercase = "abcdefghijklmnopqrstuvwxyz"
    $digits = "0123456789"
    $special = "!@#$%^&*-_=+"
    
    # Ensure at least one of each type
    $passwordChars = @()
    $passwordChars += $uppercase[(Get-Random -Maximum $uppercase.Length)]
    $passwordChars += $lowercase[(Get-Random -Maximum $lowercase.Length)]
    $passwordChars += $digits[(Get-Random -Maximum $digits.Length)]
    $passwordChars += $special[(Get-Random -Maximum $special.Length)]
    
    # Fill remaining 12 characters randomly from all sets
    $allChars = $uppercase + $lowercase + $digits + $special
    for ($i = 0; $i -lt 12; $i++) {
        $passwordChars += $allChars[(Get-Random -Maximum $allChars.Length)]
    }
    
    # Shuffle the password characters
    $password = -join ($passwordChars | Get-Random -Count $passwordChars.Count)
    
    # Create user
    $userBody = @{
        accountEnabled = $true
        displayName = $displayName
        mailNickname = "$TenantCode-cxnmsp-admin"
        userPrincipalName = $userPrincipalName
        passwordProfile = @{
            forceChangePasswordNextSignIn = $true
            password = $password
        }
        usageLocation = "BE"
    }
    
    $newUser = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/users" -Body $userBody -Description "Creating user '$userPrincipalName'"
    
    if ($newUser) {
        Write-ColorOutput "Successfully created MSP admin user: $userPrincipalName" "Green"
        # Return user info with password
        return @{
            user = $newUser
            password = $password
            isNew = $true
        }
    } else {
        Write-ColorOutput "Failed to create MSP admin user" "Red"
        return $null
    }
}

# Function to add MSP admin user to AU with roles
function Add-MspUserToAdminUnit {
    param(
        [string]$UserId,
        [string]$AdminUnitId
    )
    
    if (-not $UserId -or -not $AdminUnitId) {
        Write-ColorOutput "Warning: Cannot add user to AU - missing UserId or AdminUnitId" "Yellow"
        return $false
    }
    
    Write-ColorOutput "`nAdding MSP admin user to Administrative Unit with roles..." "Cyan"
    
    if ($WhatIf) {
        Write-ColorOutput "WHATIF: Would add user to AU and assign roles" "Yellow"
        return $true
    }
    
    # First add user as member of AU
    $memberBody = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
    }
    $null = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$AdminUnitId/members/`$ref" -Body $memberBody -Description "Adding MSP user to administrative unit" -IgnoreError
    
    # Define roles to assign (scoped to AU)
    $rolesToAssign = @{
        "User Administrator" = "fe930be7-5e62-47db-91af-98c3a49a38b1"
        "Groups Administrator" = "fdd7a751-b60b-444a-984c-02652fe8fa1c"
    }
    
    # Assign each role to the user (scoped to AU)
    foreach ($roleName in $rolesToAssign.Keys) {
        $roleId = $rolesToAssign[$roleName]
        
        $roleAssignmentBody = @{
            "@odata.type" = "#microsoft.graph.unifiedRoleAssignment"
            roleDefinitionId = $roleId
            principalId = $UserId
            directoryScopeId = "/administrativeUnits/$AdminUnitId"
        }
        
        $roleAssignment = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" -Body $roleAssignmentBody -Description "Assigning $roleName role to MSP user in AU" -IgnoreError
        
        if ($roleAssignment) {
            Write-ColorOutput "✓ Assigned $roleName role to MSP user (AU-scoped)" "Green"
        }
    }
    
    return $true
}

# Function to add calling user to AU with roles
function Add-CallingUserToAdminUnit {
    param(
        [string]$UserId,
        [string]$UserDisplayName,
        [string]$AdminUnitId
    )
    
    if (-not $UserId -or -not $AdminUnitId) {
        Write-ColorOutput "Warning: Cannot add calling user to AU - missing UserId or AdminUnitId" "Yellow"
        return $false
    }
    
    Write-ColorOutput "`nAdding calling user to Administrative Unit with roles..." "Cyan"
    
    if ($WhatIf) {
        Write-ColorOutput "WHATIF: Would add calling user '$UserDisplayName' to AU and assign roles" "Yellow"
        return $true
    }
    
    # First add user as member of AU
    $memberBody = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
    }
    $null = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$AdminUnitId/members/`$ref" -Body $memberBody -Description "Adding calling user to administrative unit" -IgnoreError
    
    # Define roles to assign (scoped to AU)
    $rolesToAssign = @{
        "User Administrator" = "fe930be7-5e62-47db-91af-98c3a49a38b1"
        "Groups Administrator" = "fdd7a751-b60b-444a-984c-02652fe8fa1c"
    }
    
    # Assign each role to the user (scoped to AU)
    foreach ($roleName in $rolesToAssign.Keys) {
        $roleId = $rolesToAssign[$roleName]
        
        # Check if assignment already exists
        $existingAssignments = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$UserId' and roleDefinitionId eq '$roleId' and directoryScopeId eq '/administrativeUnits/$AdminUnitId'" -Description "Checking existing role assignments for $roleName" -IgnoreError
        
        if ($existingAssignments -and $existingAssignments.value -and $existingAssignments.value.Count -gt 0) {
            Write-ColorOutput "Role '$roleName' already assigned to calling user (AU-scoped)" "Yellow"
            continue
        }
        
        $roleAssignmentBody = @{
            "@odata.type" = "#microsoft.graph.unifiedRoleAssignment"
            roleDefinitionId = $roleId
            principalId = $UserId
            directoryScopeId = "/administrativeUnits/$AdminUnitId"
        }
        
        $roleAssignment = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" -Body $roleAssignmentBody -Description "Assigning $roleName role to calling user in AU" -IgnoreError
        
        if ($roleAssignment) {
            Write-ColorOutput "✓ Assigned $roleName role to calling user '$UserDisplayName' (AU-scoped)" "Green"
        }
    }
    
    return $true
}

# Function to create or verify customer admin user
function New-CustomerAdminUser {
    param(
        [string]$TenantCode,
        [string]$OnMicrosoftDomain
    )
    
    if (-not $OnMicrosoftDomain) {
        Write-ColorOutput "Warning: Cannot create customer admin user without onmicrosoft.com domain" "Yellow"
        return $null
    }
    
    $displayName = "$TenantCode-cust-admin"
    $userPrincipalName = "$displayName@$OnMicrosoftDomain"
    
    Write-ColorOutput "`nChecking customer admin user: $userPrincipalName" "Cyan"
    
    # Check if user already exists
    $existingUser = Invoke-GraphRequest -Method "GET" -Uri "https://graph.microsoft.com/v1.0/users/$userPrincipalName" -Description "Checking if user '$userPrincipalName' exists" -IgnoreError
    
    if ($existingUser) {
        Write-ColorOutput "Customer admin user already exists: $userPrincipalName" "Green"
        return @{
            user = $existingUser
            password = $null
            isNew = $false
        }
    }
    
    if ($WhatIf) {
        Write-ColorOutput "WHATIF: Would create user '$userPrincipalName'" "Yellow"
        return $null
    }
    
    # Generate complex random password: 16 characters
    $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lowercase = "abcdefghijklmnopqrstuvwxyz"
    $digits = "0123456789"
    $special = "!@#$%^&*-_=+"
    
    $passwordChars = @()
    $passwordChars += $uppercase[(Get-Random -Maximum $uppercase.Length)]
    $passwordChars += $lowercase[(Get-Random -Maximum $lowercase.Length)]
    $passwordChars += $digits[(Get-Random -Maximum $digits.Length)]
    $passwordChars += $special[(Get-Random -Maximum $special.Length)]
    
    $allChars = $uppercase + $lowercase + $digits + $special
    for ($i = 0; $i -lt 12; $i++) {
        $passwordChars += $allChars[(Get-Random -Maximum $allChars.Length)]
    }
    
    $password = -join ($passwordChars | Get-Random -Count $passwordChars.Count)
    
    # Create user
    $userBody = @{
        accountEnabled = $true
        displayName = $displayName
        mailNickname = "$TenantCode-cust-admin"
        userPrincipalName = $userPrincipalName
        passwordProfile = @{
            forceChangePasswordNextSignIn = $true
            password = $password
        }
        usageLocation = "BE"
    }
    
    $newUser = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/users" -Body $userBody -Description "Creating user '$userPrincipalName'"
    
    if ($newUser) {
        Write-ColorOutput "Successfully created customer admin user: $userPrincipalName" "Green"
        return @{
            user = $newUser
            password = $password
            isNew = $true
        }
    } else {
        Write-ColorOutput "Failed to create customer admin user" "Red"
        return $null
    }
}

# Function to add customer admin user to AU (member only, no roles)
function Add-CustomerUserToAdminUnit {
    param(
        [string]$UserId,
        [string]$AdminUnitId
    )
    
    if (-not $UserId -or -not $AdminUnitId) {
        Write-ColorOutput "Warning: Cannot add user to AU - missing UserId or AdminUnitId" "Yellow"
        return $false
    }
    
    Write-ColorOutput "Adding customer admin user to Administrative Unit..." "Cyan"
    
    if ($WhatIf) {
        Write-ColorOutput "WHATIF: Would add user to AU as member" "Yellow"
        return $true
    }
    
    # Add user as member of AU (no roles)
    $memberBody = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
    }
    $null = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$AdminUnitId/members/`$ref" -Body $memberBody -Description "Adding customer user to administrative unit" -IgnoreError
    
    Write-ColorOutput "✓ Customer admin user added to AU (member only)" "Green"
    return $true
}

#
# MAIN EXECUTION
#

Write-ColorOutput "=== Complete Entra ID Setup ===" "Cyan"

# Validate parameter combinations
if ($EntraOnly -and $SubscriptionsOnly) {
    Write-ColorOutput "Error: Cannot use both -EntraOnly and -SubscriptionsOnly switches" "Red"
    exit 1
}

# Initialize array to track all created groups with metadata
$script:allCreatedGroups = @()

# Determine tenant code first (needed for config filename)
if ($TenantCode) {
    $tenantCode = $TenantCode
    Write-ColorOutput "Using TenantCode from parameter: $tenantCode" "Green"
} else {
    # Try to find config file with pattern *-config.json
    $configFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*-config.json" -File
    if ($configFiles.Count -eq 1) {
        $ConfigFile = $configFiles[0].FullName
        $tempConfig = Get-Configuration -Path $ConfigFile
        if ($tempConfig.tenantconfig -and $tempConfig.tenantconfig.tenantCode) {
            $tenantCode = $tempConfig.tenantconfig.tenantCode
            Write-ColorOutput "Found config file: $ConfigFile" "Green"
            Write-ColorOutput "Using TenantCode from config: $tenantCode" "Green"
        } else {
            Write-ColorOutput "No tenantCode found in configuration. Please provide -TenantCode parameter." "Red"
            exit 1
        }
    } elseif ($configFiles.Count -gt 1) {
        Write-ColorOutput "Multiple config files found. Please specify -TenantCode parameter or use -ConfigFile." "Red"
        exit 1
    } else {
        Write-ColorOutput "No config file found and no TenantCode parameter provided." "Red"
        Write-ColorOutput "Please provide -TenantCode parameter to create initial config." "Red"
        exit 1
    }
}

# Set config filename based on tenant code if not explicitly provided
if (-not $ConfigFile) {
    $ConfigFile = "$PSScriptRoot/$tenantCode-config.json"
}

Write-ColorOutput "Configuration file: $ConfigFile" "Cyan"

# Load or initialize configuration
$configExists = Test-Path $ConfigFile
if (-not $configExists) {
    Write-ColorOutput "Config file does not exist. Will create new config based on TenantCode: $tenantCode" "Yellow"
    $config = $null
} else {
    $config = Get-Configuration -Path $ConfigFile
}

if ($tenantCode -eq "unknown" -or -not $tenantCode) {
    Write-ColorOutput "Invalid tenantCode. Please provide a valid tenant code." "Red"
    exit 1
}

# Track if we triggered the login (for automatic logout at the end)
$script:weTriggeredLogin = $false

# Check if Azure CLI is available and logged in
Write-ColorOutput "Checking Azure CLI availability and login status..." "Cyan"
try {
    # First check if basic Azure CLI login works
    $accountInfo = $null
    $accountOutput = & az account show 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        try {
            $accountInfo = $accountOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            # JSON parsing failed, treat as not logged in
            $accountInfo = $null
        }
    }
    
    $needsLogin = $false
    
    if (-not $accountInfo) {
        Write-ColorOutput "Not logged in to Azure CLI" "Yellow"
        $needsLogin = $true
    } else {
        # Account exists, but test if Graph API token works
        Write-ColorOutput "Testing Graph API access..." "Cyan"
        $null = & az rest --method GET --url "https://graph.microsoft.com/v1.0/me" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Graph API token expired or invalid" "Yellow"
            $needsLogin = $true
        } else {
            Write-ColorOutput "✓ Graph API access confirmed" "Green"
        }
    }
    
    if ($needsLogin) {
        Write-ColorOutput "" "White"
        Write-ColorOutput "=== Device Code Authentication Required ===" "Cyan"
        Write-ColorOutput "Please use your Global Administrator account." "White"
        Write-ColorOutput "" "White"
        
        # Execute az login and let it show its output directly to user
        & az login --use-device-code
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "" "White"
            Write-ColorOutput "Login failed" "Red"
            exit 1
        }
        
        # Mark that we triggered the login
        $script:weTriggeredLogin = $true
        Write-ColorOutput "" "White"
        Write-ColorOutput "✓ Login successful" "Green"
        
        # Get account info after login
        $accountInfo = az account show | ConvertFrom-Json
    }
    
    Write-ColorOutput "✓ Logged in to Azure CLI" "Green"
    Write-ColorOutput "  - Account: $($accountInfo.user.name)" "White"
    Write-ColorOutput "  - Subscription: $($accountInfo.name)" "White"
    Write-ColorOutput "  - Tenant: $($accountInfo.tenantId)" "White"
    Write-ColorOutput "  - Tenant code: $tenantCode" "White"
    
    # Determine which subscriptions to process (skip if EntraOnly)
    if (-not $EntraOnly) {
        if ($AllSubscriptions) {
            Write-ColorOutput "`nFetching all subscriptions in current tenant..." "Cyan"
            $allSubs = az account list --all --output json | ConvertFrom-Json
            
            # Filter by current tenant
            $tenantSubs = $allSubs | Where-Object { $_.homeTenantId -eq $accountInfo.tenantId }
            
            if ($tenantSubs.Count -eq 0) {
                Write-ColorOutput "No subscriptions found in tenant $($accountInfo.tenantId)" "Red"
                exit 1
            }
            
            Write-ColorOutput "Found $($tenantSubs.Count) subscription(s) in current tenant:" "Green"
            foreach ($sub in $tenantSubs) {
                $prefix = $sub.id.Split('-')[0]
                Write-ColorOutput "  - $($sub.name) ($prefix)" "White"
            }
            
            $subscriptionsToProcess = $tenantSubs
        } else {
            # Single subscription mode (current behavior)
            $subscriptionsToProcess = @($accountInfo)
            $subscriptionPrefix = $accountInfo.id.Split('-')[0]
            Write-ColorOutput "  - Subscription prefix: $subscriptionPrefix" "White"
        }
        
        # For single subscription mode, keep existing variables
        if (-not $AllSubscriptions) {
            $subscriptionId = $accountInfo.id
            $subscriptionPrefix = $subscriptionId.Split('-')[0]
        }
    } else {
        Write-ColorOutput "  - Subscription processing will be skipped (-EntraOnly specified)" "Yellow"
        # Initialize empty array to avoid errors
        $subscriptionsToProcess = @()
    }
    
    # Initialize or update config with current info
    if (-not $config) {
        # Create new config structure
        $config = @{
            tenantCode = $tenantCode
            tenantId = $accountInfo.tenantId
            subscriptionId = if ($EntraOnly -or $AllSubscriptions) { $null } else { $subscriptionId }
            restrictedAdminUnitId = $null
        }
        Write-ColorOutput "Created new configuration structure" "Green"
    } else {
        # Update existing config - always use flat structure internally
        $config = @{
            tenantCode = $tenantCode
            tenantId = $accountInfo.tenantId
            subscriptionId = if ($EntraOnly -or $AllSubscriptions) { $null } else { $subscriptionId }
            restrictedAdminUnitId = if ($config.tenantconfig -and $config.tenantconfig.restrictedAdminUnitId) { 
                $config.tenantconfig.restrictedAdminUnitId 
            } elseif ($config.restrictedAdminUnitId) {
                $config.restrictedAdminUnitId
            } else {
                $null
            }
        }
        Write-ColorOutput "Updated configuration with current subscription info" "Green"
    }
}
catch {
    Write-ColorOutput "Error checking Azure CLI: $($_.Exception.Message)" "Red"
    exit 1
}

# Get current user for admin unit setup
$currentUser = Get-CurrentUser
if (-not $currentUser) {
    Write-ColorOutput "Cannot proceed without current user information" "Red"
    exit 1
}

# Get onmicrosoft.com domain and save to config
$onMicrosoftDomain = Get-OnMicrosoftDomain
if ($onMicrosoftDomain) {
    Write-ColorOutput "Found onmicrosoft.com domain: $onMicrosoftDomain" "Green"
    $config.onMicrosoftDomain = $onMicrosoftDomain
} else {
    # Try to use existing from config
    if ($config.onMicrosoftDomain) {
        $onMicrosoftDomain = $config.onMicrosoftDomain
        Write-ColorOutput "Using onmicrosoft.com domain from config: $onMicrosoftDomain" "Yellow"
    }
}

# Setup Administrative Unit
Write-ColorOutput "`nSetting up Administrative Unit..." "Cyan"
$restrictedAdminUnitId = Set-RestrictedAdminUnit -TenantCode $tenantCode

if ($restrictedAdminUnitId) {
    $config.restrictedAdminUnitId = $restrictedAdminUnitId
    
    # Add calling user to AU with User Administrator and Groups Administrator roles
    if ($currentUser -and $currentUser.id) {
        $auAdded = Add-CallingUserToAdminUnit -UserId $currentUser.id -UserDisplayName $currentUser.displayName -AdminUnitId $restrictedAdminUnitId
        if ($auAdded) {
            Write-ColorOutput "✓ Calling user added to AU with User Administrator and Groups Administrator roles (AU-scoped)" "Green"
        }
    }
}

# Create or verify MSP admin user
$mspAdminUserResult = New-MspAdminUser -TenantCode $tenantCode -OnMicrosoftDomain $onMicrosoftDomain

# Add MSP user to AU with roles if user was created
if ($mspAdminUserResult -and $mspAdminUserResult.isNew -and $restrictedAdminUnitId) {
    $auAdded = Add-MspUserToAdminUnit -UserId $mspAdminUserResult.user.id -AdminUnitId $restrictedAdminUnitId
    if ($auAdded) {
        Write-ColorOutput "✓ MSP admin user added to AU with User Administrator and Groups Administrator roles (AU-scoped)" "Green"
    }
}

# Create or verify customer admin user
$customerAdminUserResult = New-CustomerAdminUser -TenantCode $tenantCode -OnMicrosoftDomain $onMicrosoftDomain

# Add customer user to AU (member only, no roles) if user was created
if ($customerAdminUserResult -and $customerAdminUserResult.isNew -and $restrictedAdminUnitId) {
    $null = Add-CustomerUserToAdminUnit -UserId $customerAdminUserResult.user.id -AdminUnitId $restrictedAdminUnitId
}

# Initialize hashtables to track processed groups
$processedTenantGroups = @{}
$processedSubscriptionGroups = @{}

# Skip group creation if SetupEntraOnly is specified
if (-not $SetupEntraOnly) {
    Write-ColorOutput "`nStarting deployment of Entra groups using Microsoft Graph REST API..." "Cyan"

    # ========================================
    # PHASE 1: TENANT-LEVEL GROUPS
    # ========================================
    if (-not $SubscriptionsOnly) {
        Write-ColorOutput "`n=== PHASE 1: Processing tenant-level groups ===" "Magenta"
        
        foreach ($tenantGroup in $aTenantGroups) {
            $baseName = $tenantGroup.name
            $description = $tenantGroup.description
            $roles = $tenantGroup.roles
            $isSuperAdmin = $tenantGroup.ContainsKey("super-admin") -and $tenantGroup["super-admin"] -eq $true
            $includeSuperAdmin = $tenantGroup.ContainsKey("include-super-admin") -and $tenantGroup["include-super-admin"] -eq $true
            
            # Generate full group name: sec-tenant-{tenantcode}-{basename}
            $groupName = "sec-tenant-$tenantCode-$baseName"
            
            Write-ColorOutput "`nProcessing tenant group: $groupName" "Cyan"
            
            # Create group with role-assignable flag if it has roles OR if it's the super-admin group
            # Role-assignable groups are NOT added to AU (to allow member management)
            # Non-role-assignable groups ARE added to AU
            $hasRoles = $roles -and $roles.Count -gt 0
            $shouldBeRoleAssignable = $hasRoles -or $isSuperAdmin
            
            if ($shouldBeRoleAssignable) {
                # Role-assignable group - do NOT add to AU
                $group = New-GraphGroup -GroupName $groupName -Description $description -RoleAssignable:$true
                if ($isSuperAdmin) {
                    Write-ColorOutput "Note: Super-admin group - role-assignable for future role assignments" "Yellow"
                }
                Write-ColorOutput "Note: Role-assignable group - NOT added to AU (allows member management)" "Yellow"
            } else {
                # Regular group - add to AU
                $group = New-GraphGroup -GroupName $groupName -Description $description -AdminUnitId $restrictedAdminUnitId
            }
            
            if ($group) {
                # Save to processed groups hashtable
                $processedTenantGroups[$groupName] = $group.id
                
                # Add to central tracking array with metadata
                $script:allCreatedGroups += @{
                    Name = $groupName
                    Id = $group.id
                    Type = "tenant"
                    IncludeSuperAdmin = $includeSuperAdmin
                    SubscriptionId = $null
                    Roles = $roles
                }
                
                if ($hasRoles) {
                    Write-ColorOutput "Entra directory roles for group '$groupName' will be assigned (tenant-wide)" "Yellow"
                    foreach ($role in $roles) {
                        Write-ColorOutput "  - $role" "White"
                    }
                    Write-ColorOutput "Group ID: $($group.id)" "White"
                } else {
                    Write-ColorOutput "No roles defined for group '$groupName'" "Yellow"
                }
            }
        }
        
        Write-ColorOutput "`n✓ Tenant groups creation complete" "Green"
        
        # Assign Entra directory roles to tenant groups
        Write-ColorOutput "`nAssigning Entra directory roles to tenant groups..." "Cyan"
        
        foreach ($tenantGroup in $aTenantGroups) {
            $baseName = $tenantGroup.name
            $roles = $tenantGroup.roles
            
            # Generate full group name: sec-tenant-{tenantcode}-{basename}
            $groupName = "sec-tenant-$tenantCode-$baseName"
            
            # Skip groups without roles
            if (-not $roles -or $roles.Count -eq 0) {
                continue
            }
            
            Write-ColorOutput "`nProcessing role-assignable group: $groupName" "Cyan"
            
            # Find the group by name
            $existingGroup = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$groupName'" -Description "Finding group '$groupName'"
            
            if ($existingGroup -and $existingGroup.value -and $existingGroup.value.Count -gt 0) {
                $group = $existingGroup.value[0]
                
                # Assign Entra directory roles (tenant-wide, not AU-scoped)
                foreach ($role in $roles) {
                    Set-EntraDirectoryRole -GroupId $group.id -RoleDisplayName $role -GroupDisplayName $group.displayName
                }
            } else {
                Write-ColorOutput "Warning: Group '$groupName' not found" "Red"
            }
        }
        
        # Process tenant-level RBAC role assignments for Azure Reservations
        Write-ColorOutput "`nAssigning tenant-level RBAC roles for Azure Reservations..." "Cyan"
        
        $reservationsRoleAssignments = @(
            @{
                GroupName = "sec-tenant-$tenantCode-reservations-read"
                RoleName = "Reservations Reader"
                Scope = "/providers/Microsoft.Capacity"
            },
            @{
                GroupName = "sec-tenant-$tenantCode-reservations-admin"
                RoleName = "Reservations Administrator"
                Scope = "/providers/Microsoft.Capacity"
            },
            @{
                GroupName = "sec-tenant-$tenantCode-reservations-purchase"
                RoleName = "Reservation Purchaser"
                Scope = "/providers/Microsoft.Capacity"
            }
        )
        
        foreach ($assignment in $reservationsRoleAssignments) {
            Write-ColorOutput "`nAssigning '$($assignment.RoleName)' to group '$($assignment.GroupName)'..." "Cyan"
            $result = Set-TenantRbacRole -GroupName $assignment.GroupName -RoleName $assignment.RoleName -Scope $assignment.Scope
            
            if (-not $result) {
                Write-ColorOutput "Warning: Failed to assign role for group '$($assignment.GroupName)'" "Yellow"
            }
        }
        
        Write-ColorOutput "`n✓ Tenant role assignments complete" "Green"
    } else {
        Write-ColorOutput "`n⊘ Skipping tenant-level groups (-SubscriptionsOnly specified)" "Yellow"
    }

    # ========================================
    # PHASE 2: SUBSCRIPTION-LEVEL GROUPS
    # ========================================
    if (-not $EntraOnly) {
        Write-ColorOutput "`n=== PHASE 2: Processing subscription-level groups ===" "Magenta"
        
        # Loop through each subscription to process
        foreach ($subToProcess in $subscriptionsToProcess) {
            $subscriptionId = $subToProcess.id
            $subscriptionPrefix = $subscriptionId.Split('-')[0]
            $subscriptionName = $subToProcess.name
            
            Write-ColorOutput "`n--- Subscription: $subscriptionName ($subscriptionPrefix) ---" "Cyan"
            
            $groupsToAssignRbac = @()
            
            foreach ($subGroup in $aSubscriptionGroups) {
                $baseName = $subGroup.name
                $description = $subGroup.description
                $rbacRoles = $subGroup.RBACroles
                $includeSuperAdmin = $subGroup.ContainsKey("include-super-admin") -and $subGroup["include-super-admin"] -eq $true
                
                # Generate the full group name with tenant code and subscription prefix
                $groupName = "sec-az-$tenantCode-$subscriptionPrefix-$baseName"
                
                Write-ColorOutput "`nProcessing subscription group: $groupName" "Cyan"
                
                # Create group and add to administrative unit
                $group = New-GraphGroup -GroupName $groupName -Description $description -AdminUnitId $restrictedAdminUnitId
                
                if ($group) {
                    # Save to processed groups hashtable  
                    $processedSubscriptionGroups[$groupName] = $group.id
                    
                    # Add to central tracking array with metadata
                    $script:allCreatedGroups += @{
                        Name = $groupName
                        Id = $group.id
                        Type = "subscription"
                        IncludeSuperAdmin = $includeSuperAdmin
                        SubscriptionId = $subscriptionId
                        SubscriptionPrefix = $subscriptionPrefix
                        RBACRoles = $rbacRoles
                    }
                    
                    # Store group info for RBAC assignment later
                    if ($rbacRoles -and $rbacRoles.Count -gt 0) {
                        $groupsToAssignRbac += @{
                            GroupId = $group.id
                            GroupName = $groupName
                            Roles = $rbacRoles
                        }
                    } else {
                        Write-ColorOutput "No RBAC roles defined for group '$groupName'" "Yellow"
                    }
                }
            }
            
            # Wait for replication if any groups need RBAC assignments
            if ($groupsToAssignRbac.Count -gt 0) {
                Write-ColorOutput "`nWaiting 15 seconds for Azure AD replication..." "Yellow"
                Start-Sleep -Seconds 15
                
                Write-ColorOutput "Assigning RBAC roles to subscription groups for $subscriptionPrefix..." "Cyan"
                foreach ($groupInfo in $groupsToAssignRbac) {
                    Write-ColorOutput "`nAssigning RBAC roles to $($groupInfo.GroupName)..." "Cyan"
                    foreach ($role in $groupInfo.Roles) {
                        Set-AzRoleAssignment -GroupObjectId $groupInfo.GroupId -RoleName $role -GroupName $groupInfo.GroupName -SubscriptionId $subscriptionId
                    }
                }
            }
        }
        
        Write-ColorOutput "`n✓ Subscription groups creation complete" "Green"
    } else {
        Write-ColorOutput "`n⊘ Skipping subscription-level groups (-EntraOnly specified)" "Yellow"
    }
    
    # ========================================
    # PHASE 3: GROUP MEMBERSHIP ASSIGNMENTS
    # ========================================
    Write-ColorOutput "`n=== PHASE 3: Processing group memberships ===" "Magenta"
    
    # Filter groups that need super-admin members
    $groupsWithSuperAdmin = $script:allCreatedGroups | Where-Object { $_.IncludeSuperAdmin -eq $true }
    
    if ($groupsWithSuperAdmin.Count -eq 0) {
        Write-ColorOutput "No groups with include-super-admin flag found" "Yellow"
    } else {
        Write-ColorOutput "Found $($groupsWithSuperAdmin.Count) group(s) with include-super-admin flag" "Green"
        foreach ($grp in $groupsWithSuperAdmin) {
            Write-ColorOutput "  - $($grp.Name)" "White"
        }
        
        # Collect users to add
        $usersToAdd = @()
        
        # Add SuperAdmins parameter users
        if ($SuperAdmins) {
            $superAdminUsers = $SuperAdmins -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            if ($superAdminUsers.Count -gt 0) {
                Write-ColorOutput "`nSuper-admin users from parameter:" "Cyan"
                foreach ($upn in $superAdminUsers) {
                    Write-ColorOutput "  - $upn" "White"
                    $usersToAdd += @{
                        UPN = $upn
                        Source = "SuperAdmins parameter"
                    }
                }
            }
        }
        
        # Add MSP admin user
        if ($mspAdminUserResult -and $mspAdminUserResult.user -and $mspAdminUserResult.user.userPrincipalName) {
            $mspUpn = $mspAdminUserResult.user.userPrincipalName
            Write-ColorOutput "`nMSP admin user:" "Cyan"
            Write-ColorOutput "  - $mspUpn" "White"
            $usersToAdd += @{
                UPN = $mspUpn
                UserId = $mspAdminUserResult.user.id  # Already have the ID
                Source = "MSP admin"
            }
        }
        
        # Process each user
        foreach ($userInfo in $usersToAdd) {
            $userPrincipalName = $userInfo.UPN
            Write-ColorOutput "`nProcessing user: $userPrincipalName ($($userInfo.Source))" "Cyan"
            
            # Get user ID if not already provided
            if (-not $userInfo.UserId) {
                $user = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/users?`$filter=userPrincipalName eq '$userPrincipalName'&`$select=id,userPrincipalName,displayName" -Description "Getting user '$userPrincipalName'" -IgnoreError
                
                if (-not $user -or -not $user.value -or $user.value.Count -eq 0) {
                    Write-ColorOutput "User '$userPrincipalName' not found, skipping" "Red"
                    continue
                }
                
                $userId = $user.value[0].id
                $displayName = $user.value[0].displayName
                Write-ColorOutput "Found user: $displayName ($userPrincipalName)" "Green"
            } else {
                $userId = $userInfo.UserId
                Write-ColorOutput "Using existing user ID: $userId" "Green"
            }
            
            # Add user to all groups with include-super-admin=true
            foreach ($targetGroup in $groupsWithSuperAdmin) {
                $targetGroupName = $targetGroup.Name
                $targetGroupId = $targetGroup.Id
                
                if ($WhatIf) {
                    Write-ColorOutput "WHATIF: Would add user '$userPrincipalName' to group '$targetGroupName'" "Yellow"
                } else {
                    # Check if user is already member
                    $existingMember = Invoke-GraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$targetGroupId/members?`$filter=id eq '$userId'&`$select=id" -Description "Checking if user is member of '$targetGroupName'" -IgnoreError
                    
                    if ($existingMember -and $existingMember.value -and $existingMember.value.Count -gt 0) {
                        Write-ColorOutput "User '$userPrincipalName' is already member of '$targetGroupName'" "Yellow"
                    } else {
                        $memberBody = @{
                            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$userId"
                        }
                        $addUserToGroup = Invoke-GraphRequest -Method "POST" -Uri "https://graph.microsoft.com/v1.0/groups/$targetGroupId/members/`$ref" -Body $memberBody -Description "Adding user '$userPrincipalName' to group '$targetGroupName'" -IgnoreError
                        
                        if ($addUserToGroup -or $LASTEXITCODE -eq 0) {
                            Write-ColorOutput "✓ Added user '$userPrincipalName' to '$targetGroupName'" "Green"
                        } else {
                            Write-ColorOutput "Failed to add user '$userPrincipalName' to '$targetGroupName'" "Red"
                        }
                    }
                }
            }
        }
        
        Write-ColorOutput "`n✓ Membership processing complete" "Green"
    }
}

# Save configuration
if ((-not $SetupEntraOnly) -and ($configExists -or -not $WhatIf)) {
    if ($AllSubscriptions) {
        # Prepare subscription prefix info for all processed subscriptions
        $allSubPrefixes = @()
        foreach ($sub in $subscriptionsToProcess) {
            $allSubPrefixes += @{
                id = $sub.id
                prefix = $sub.id.Split('-')[0]
            }
        }
        Save-ConfigurationFile -Path $ConfigFile -Config $config -ProcessedTenantGroups $processedTenantGroups -ProcessedSubscriptionGroups $processedSubscriptionGroups -AllSubscriptionPrefixes $allSubPrefixes
    } else {
        Save-ConfigurationFile -Path $ConfigFile -Config $config -ProcessedTenantGroups $processedTenantGroups -ProcessedSubscriptionGroups $processedSubscriptionGroups -SubscriptionPrefix $subscriptionPrefix
    }
    Write-ColorOutput "- Configuration saved to: $ConfigFile" "White"
} else {
    Write-ColorOutput "- Configuration not saved (SetupEntraOnly mode or WhatIf)" "Yellow"
}

Write-ColorOutput "`n=== Complete Entra ID Setup Finished ===" "Green"
Write-ColorOutput "Summary:" "Cyan"
Write-ColorOutput "✓ Current user: $($currentUser.displayName) ($($currentUser.userPrincipalName))" "White"
if ($restrictedAdminUnitId) {
    Write-ColorOutput "  - Added to Administrative Unit with User Administrator and Groups Administrator roles (AU-scoped)" "Cyan"
}

# Show MSP admin user info if created
if ($mspAdminUserResult -and $mspAdminUserResult.user) {
    $mspUserName = $mspAdminUserResult.user.userPrincipalName
    if ($mspAdminUserResult.isNew) {
        Write-ColorOutput "✓ MSP admin user created: $mspUserName" "Green"
        if ($ShowPassword -and $mspAdminUserResult.password) {
            Write-ColorOutput "  Password: $($mspAdminUserResult.password)" "Yellow"
            Write-ColorOutput "  IMPORTANT: User must change password on first login" "Yellow"
        } elseif (-not $ShowPassword) {
            Write-ColorOutput "  Use -ShowPassword parameter to display initial password" "Cyan"
        }
        if ($restrictedAdminUnitId) {
            Write-ColorOutput "  Added to Administrative Unit with User Administrator and Groups Administrator roles (AU-scoped)" "Cyan"
        }
    } else {
        Write-ColorOutput "✓ MSP admin user exists: $mspUserName" "Green"
    }
}

# Show customer admin user info if created
if ($customerAdminUserResult -and $customerAdminUserResult.user) {
    $custUserName = $customerAdminUserResult.user.userPrincipalName
    if ($customerAdminUserResult.isNew) {
        Write-ColorOutput "✓ Customer admin user created: $custUserName" "Green"
        if ($ShowPassword -and $customerAdminUserResult.password) {
            Write-ColorOutput "  Password: $($customerAdminUserResult.password)" "Yellow"
            Write-ColorOutput "  IMPORTANT: User must change password on first login" "Yellow"
        } elseif (-not $ShowPassword) {
            Write-ColorOutput "  Use -ShowPassword parameter to display initial password" "Cyan"
        }
        if ($restrictedAdminUnitId) {
            Write-ColorOutput "  Added to Administrative Unit (member only)" "Cyan"
        }
    } else {
        Write-ColorOutput "✓ Customer admin user exists: $custUserName" "Green"
    }
}

if ($restrictedAdminUnitId) {
    Write-ColorOutput "✓ Administrative Unit ($tenantCode-tenant-admin): $restrictedAdminUnitId" "White"
}

if (-not $SetupEntraOnly) {
    Write-ColorOutput "✓ Deployment completed!" "White"
    
    # Count groups from the central tracking array
    $tenantGroupsCreated = ($script:allCreatedGroups | Where-Object { $_.Type -eq "tenant" }).Count
    $subscriptionGroupsCreated = ($script:allCreatedGroups | Where-Object { $_.Type -eq "subscription" }).Count
    
    if ($EntraOnly) {
        Write-ColorOutput "  - Tenant groups processed: $tenantGroupsCreated" "White"
        Write-ColorOutput "  - Subscription groups: Skipped (-EntraOnly)" "Yellow"
    } elseif ($SubscriptionsOnly) {
        Write-ColorOutput "  - Tenant groups: Skipped (-SubscriptionsOnly)" "Yellow"
        Write-ColorOutput "  - Subscription groups processed: $subscriptionGroupsCreated" "White"
        if ($AllSubscriptions) {
            $subsProcessed = $subscriptionsToProcess.Count
            Write-ColorOutput "  - Subscriptions processed: $subsProcessed" "White"
        }
    } else {
        Write-ColorOutput "  - Tenant groups processed: $tenantGroupsCreated" "White"
        Write-ColorOutput "  - Subscription groups processed: $subscriptionGroupsCreated" "White"
        if ($AllSubscriptions) {
            $subsProcessed = $subscriptionsToProcess.Count
            Write-ColorOutput "  - Subscriptions processed: $subsProcessed" "White"
        }
    }
    
    # Show super-admin membership info
    $superAdminGroups = ($script:allCreatedGroups | Where-Object { $_.IncludeSuperAdmin -eq $true }).Count
    if ($superAdminGroups -gt 0) {
        Write-ColorOutput "  - Groups with super-admin members: $superAdminGroups" "White"
    }
    
    if ($restrictedAdminUnitId) {
        Write-ColorOutput "  - Groups added to Administrative Unit" "White"
    }
}

Write-ColorOutput "✓ Entra directory roles assigned to role-assignable groups" "White"

Write-ColorOutput "`nTo verify the created groups, run:" "Cyan"
Write-ColorOutput "az ad group list --output table" "White"

# Logout if we triggered the login
if ($script:weTriggeredLogin) {
    Write-ColorOutput "`nLogging out from Azure CLI (we triggered this login session)..." "Cyan"
    $logoutResult = & az logout 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Logged out successfully" "Green"
    } else {
        Write-ColorOutput "Warning: Logout failed: $logoutResult" "Yellow"
    }
}