# Get URLs for All Deployed Applications
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Application URLs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
. "$PSScriptRoot\utils\load-config.ps1"

$SHARED_STACK_NAME = "$env:DEMO_STACK_PREFIX-shared"
$TENANT_STACK_NAME = "$env:DEMO_STACK_PREFIX-pooled"

# Get shared stack outputs
try {
    $sharedOutputs = aws cloudformation describe-stacks `
        --stack-name $SHARED_STACK_NAME `
        --profile $env:AWS_PROFILE `
        --region $env:AWS_REGION `
        --query "Stacks[0].Outputs" `
        --output json | ConvertFrom-Json
    
    $adminApiUrl = ($sharedOutputs | Where-Object { $_.OutputKey -eq "AdminApi" }).OutputValue
    $adminSiteUrl = ($sharedOutputs | Where-Object { $_.OutputKey -eq "AdminAppSite" }).OutputValue
    $landingSiteUrl = ($sharedOutputs | Where-Object { $_.OutputKey -eq "LandingApplicationSite" }).OutputValue
    $appSiteUrl = ($sharedOutputs | Where-Object { $_.OutputKey -eq "ApplicationSite" }).OutputValue
    $cognitoPoolId = ($sharedOutputs | Where-Object { $_.OutputKey -eq "CognitoTenantUserPoolId" }).OutputValue
    $cognitoClientId = ($sharedOutputs | Where-Object { $_.OutputKey -eq "CognitoTenantAppClientId" }).OutputValue
    
} catch {
    Write-Host "Error retrieving shared stack outputs" -ForegroundColor Red
    exit 1
}

# Get tenant stack outputs
try {
    $tenantOutputs = aws cloudformation describe-stacks `
        --stack-name $TENANT_STACK_NAME `
        --profile $env:AWS_PROFILE `
        --region $env:AWS_REGION `
        --query "Stacks[0].Outputs" `
        --output json | ConvertFrom-Json
    
    $tenantApiUrl = ($tenantOutputs | Where-Object { $_.OutputKey -eq "TenantAPI" }).OutputValue
    
} catch {
    Write-Host "Error retrieving tenant stack outputs" -ForegroundColor Red
    $tenantApiUrl = "N/A"
}

Write-Host "Admin UI (System Administrator Dashboard)" -ForegroundColor Yellow
Write-Host "  URL: https://$adminSiteUrl" -ForegroundColor Green
Write-Host "  Username: admin" -ForegroundColor Gray
Write-Host "  Password: (Check email at $env:DEMO_ADMIN_EMAIL)" -ForegroundColor Gray
Write-Host ""

Write-Host "Landing UI (Public Tenant Registration)" -ForegroundColor Yellow
Write-Host "  URL: https://$landingSiteUrl" -ForegroundColor Green
Write-Host "  No login required - Open to public" -ForegroundColor Gray
Write-Host ""

Write-Host "Application UI (Tenant User Interface)" -ForegroundColor Yellow
Write-Host "  URL: https://$appSiteUrl" -ForegroundColor Green
Write-Host "  Login: Use credentials from tenant registration" -ForegroundColor Gray
Write-Host ""

Write-Host "API Endpoints" -ForegroundColor Yellow
Write-Host "  Admin API: $adminApiUrl" -ForegroundColor Gray
Write-Host "  Tenant API: $tenantApiUrl" -ForegroundColor Gray
Write-Host ""

Write-Host "Cognito Details" -ForegroundColor Yellow
Write-Host "  Tenant User Pool ID: $cognitoPoolId" -ForegroundColor Gray
Write-Host "  Tenant App Client ID: $cognitoClientId" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Quick Start Guide:" -ForegroundColor Yellow
Write-Host "  1. Login to Admin UI with admin credentials from email" -ForegroundColor Gray
Write-Host "  2. Open Landing UI to register a new tenant" -ForegroundColor Gray
Write-Host "  3. Return to Admin UI to activate the tenant" -ForegroundColor Gray
Write-Host "  4. Login to Application UI with tenant credentials" -ForegroundColor Gray
Write-Host ""
