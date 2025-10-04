# Configure Microsoft Graph API permissions for Stratos
# This script sets up the required permissions for sending emails via Graph API

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory=$false)]
    [string]$AppRegistrationName = "Stratos-Email-Service"
)

Write-Host "Configuring Microsoft Graph permissions for email sending..." -ForegroundColor Green

try {
    # Check if user is logged in to Azure CLI
    $loginCheck = az account show 2>$null
    if (-not $loginCheck) {
        Write-Host "Please log in to Azure CLI first: az login" -ForegroundColor Red
        exit 1
    }

    # Get the managed identity principal ID
    Write-Host "Getting managed identity information..." -ForegroundColor Yellow
    $identityInfo = az webapp identity show --name $AppServiceName --resource-group $ResourceGroupName | ConvertFrom-Json
    $principalId = $identityInfo.principalId

    if (-not $principalId) {
        throw "Could not retrieve managed identity principal ID. Make sure the app service has managed identity enabled."
    }

    Write-Host "Managed Identity Principal ID: $principalId" -ForegroundColor Yellow

    # Create Azure AD App Registration (if it doesn't exist)
    Write-Host "Checking for existing app registration: $AppRegistrationName" -ForegroundColor Yellow
    $existingApp = az ad app list --display-name $AppRegistrationName | ConvertFrom-Json

    if ($existingApp.Count -eq 0) {
        Write-Host "Creating new app registration: $AppRegistrationName" -ForegroundColor Green
        $appRegistration = az ad app create --display-name $AppRegistrationName | ConvertFrom-Json
        $appId = $appRegistration.appId
    } else {
        $appId = $existingApp[0].appId
        Write-Host "Using existing app registration: $appId" -ForegroundColor Green
    }

    # Grant required Microsoft Graph permissions
    Write-Host "Configuring Microsoft Graph API permissions..." -ForegroundColor Green
    
    # Required permissions for sending emails:
    # - Mail.Send (Application permission to send emails as any user)
    # - User.Read.All (Application permission to read user profiles)
    
    $graphResourceId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    $mailSendPermissionId = "b633e1c5-b582-4048-a93e-9f11b44c7e96" # Mail.Send
    $userReadAllPermissionId = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All

    # Add required API permissions
    az ad app permission add --id $appId --api $graphResourceId --api-permissions "$mailSendPermissionId=Role"
    az ad app permission add --id $appId --api $graphResourceId --api-permissions "$userReadAllPermissionId=Role"

    Write-Host @"

=============================================================================
NEXT STEPS - ADMIN CONSENT REQUIRED
=============================================================================

1. GRANT ADMIN CONSENT (Required):
   Go to Azure Portal > Azure Active Directory > App registrations > $AppRegistrationName
   Click on "API permissions" > Click "Grant admin consent for [Your Organization]"
   
   OR use Azure CLI:
   az ad app permission admin-consent --id $appId

2. ASSIGN APPLICATION ROLE TO MANAGED IDENTITY:
   The managed identity needs to be assigned the application role to use these permissions.
   
   Use this PowerShell command (requires PowerShell with Microsoft.Graph module):
   
   Install-Module Microsoft.Graph -Scope CurrentUser -Force
   Connect-MgGraph -Scopes "Application.ReadWrite.All","AppRoleAssignment.ReadWrite.All"
   
   `$app = Get-MgApplication -Filter "DisplayName eq '$AppRegistrationName'"
   `$servicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '`$(`$app.AppId)'"
   `$managedIdentity = Get-MgServicePrincipal -Filter "Id eq '$principalId'"
   
   # Assign Mail.Send role
   New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId `$managedIdentity.Id ``
       -PrincipalId `$managedIdentity.Id ``
       -AppRoleId $mailSendPermissionId ``
       -ResourceId `$servicePrincipal.Id
   
   # Assign User.Read.All role  
   New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId `$managedIdentity.Id ``
       -PrincipalId `$managedIdentity.Id ``
       -AppRoleId $userReadAllPermissionId ``
       -ResourceId `$servicePrincipal.Id

3. VERIFY PERMISSIONS:
   After granting consent and assigning roles, your app will be able to:
   - Send emails from any user's mailbox in your organization
   - Read user profile information
   
   Test the email functionality in your Stratos application.

=============================================================================

App Registration ID: $appId
Managed Identity Principal ID: $principalId

"@ -ForegroundColor Cyan

    Write-Host "Configuration completed! Please complete the manual steps above." -ForegroundColor Green

} catch {
    Write-Error "Error: $_"
    exit 1
}