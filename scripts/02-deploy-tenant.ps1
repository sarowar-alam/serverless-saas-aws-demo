# Deploy Tenant Stack (Pooled Architecture)
# This script deploys the application plane resources: Product/Order services, Tenant API

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Deploying Tenant Stack (Pooled)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
. "$PSScriptRoot\utils\load-config.ps1"

$SHARED_STACK_NAME = "$env:DEMO_STACK_PREFIX-shared"
$TENANT_STACK_NAME = "$env:DEMO_STACK_PREFIX-pooled"
$SERVER_DIR = "$PSScriptRoot\..\server"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Profile: $env:AWS_PROFILE" -ForegroundColor Gray
Write-Host "  Region: $env:AWS_REGION" -ForegroundColor Gray
Write-Host "  Stack: $TENANT_STACK_NAME" -ForegroundColor Gray
Write-Host ""

# Get outputs from shared stack
Write-Host "Retrieving shared stack outputs..." -ForegroundColor Yellow
try {
    $sharedOutputs = aws cloudformation describe-stacks --stack-name $SHARED_STACK_NAME --profile $env:AWS_PROFILE --region $env:AWS_REGION --query "Stacks[0].Outputs" --output json | ConvertFrom-Json
    
    $TENANT_USER_POOL_ID = ($sharedOutputs | Where-Object { $_.OutputKey -eq "CognitoTenantUserPoolId" }).OutputValue
    $TENANT_APP_CLIENT_ID = ($sharedOutputs | Where-Object { $_.OutputKey -eq "CognitoTenantAppClientId" }).OutputValue
    
    if ([string]::IsNullOrEmpty($TENANT_USER_POOL_ID) -or [string]::IsNullOrEmpty($TENANT_APP_CLIENT_ID)) {
        throw "Required Cognito outputs not found in shared stack"
    }
    
    Write-Host "  User Pool ID: $TENANT_USER_POOL_ID" -ForegroundColor Green
    Write-Host "  App Client ID: $TENANT_APP_CLIENT_ID" -ForegroundColor Green
    
} catch {
    Write-Host "  Failed to retrieve shared stack outputs" -ForegroundColor Red
    Write-Host "  Make sure shared stack is deployed first" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Update samconfig.toml with actual values (handles both placeholders and existing values)
Write-Host "Updating tenant-samconfig.toml..." -ForegroundColor Yellow
$samConfigPath = Join-Path $SERVER_DIR "tenant-samconfig.toml"
$samConfig = Get-Content $samConfigPath -Raw

# Replace placeholders or existing values using regex patterns
$samConfig = $samConfig -replace 'stack_name = ".*?"', "stack_name = `"$env:DEMO_STACK_PREFIX-pooled`""
$samConfig = $samConfig -replace 's3_bucket = ".*?"', "s3_bucket = `"$env:SAM_S3_BUCKET`""
$samConfig = $samConfig -replace 's3_prefix = ".*?"', "s3_prefix = `"$env:DEMO_STACK_PREFIX-tenant`""
$samConfig = $samConfig -replace 'region = ".*?"', "region = `"$env:AWS_REGION`""
$samConfig = $samConfig -replace 'profile = ".*?"', "profile = `"$env:AWS_PROFILE`""
$samConfig = $samConfig -replace 'StackPrefix=[^ ]*', "StackPrefix=$env:DEMO_STACK_PREFIX"
$samConfig = $samConfig -replace 'CognitoTenantUserPoolId=[^ ]*', "CognitoTenantUserPoolId=$TENANT_USER_POOL_ID"
$samConfig = $samConfig -replace 'CognitoTenantAppClientId=[^"]*', "CognitoTenantAppClientId=$TENANT_APP_CLIENT_ID"

Set-Content -Path $samConfigPath -Value $samConfig
Write-Host "  Configuration updated with current values from .env" -ForegroundColor Green
Write-Host ""

# Build the application
Write-Host "Building SAM application (this may take 5-10 minutes)..." -ForegroundColor Yellow
Push-Location $SERVER_DIR
try {
    sam build -t tenant-template.yaml --use-container --profile $env:AWS_PROFILE --region $env:AWS_REGION
    
    if ($LASTEXITCODE -ne 0) {
        throw "SAM build failed"
    }
    
    Write-Host "  Build completed" -ForegroundColor Green
    
} catch {
    Write-Host "  Build failed: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

Write-Host ""

# Deploy the stack
Write-Host "Deploying stack (this may take 8-10 minutes)..." -ForegroundColor Yellow
Write-Host ""

Push-Location $SERVER_DIR
try {
    sam deploy --config-file tenant-samconfig.toml --profile $env:AWS_PROFILE --region $env:AWS_REGION
    
    if ($LASTEXITCODE -ne 0) {
        throw "SAM deploy failed"
    }
    
    Write-Host ""
    Write-Host "  Stack deployed successfully" -ForegroundColor Green
    
} catch {
    Write-Host "  Deploy failed: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

Write-Host ""

# Get stack outputs
Write-Host "Retrieving stack outputs..." -ForegroundColor Yellow
try {
    $outputs = aws cloudformation describe-stacks --stack-name $TENANT_STACK_NAME --profile $env:AWS_PROFILE --region $env:AWS_REGION --query "Stacks[0].Outputs" --output json | ConvertFrom-Json
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " Tenant Stack Outputs" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    foreach ($output in $outputs) {
        Write-Host "  $($output.OutputKey): $($output.OutputValue)" -ForegroundColor Gray
    }
    
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Save outputs to file for next scripts
    $outputsFile = "$PSScriptRoot\..\outputs-tenant.json"
    $outputs | ConvertTo-Json | Set-Content $outputsFile
    Write-Host "  Outputs saved to outputs-tenant.json" -ForegroundColor Green
    
} catch {
    Write-Host "  Could not retrieve stack outputs" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Tenant stack deployment completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  Run: .\scripts\03-build-clients.ps1" -ForegroundColor Gray
Write-Host ""
