# Deploy Shared Infrastructure Stack
# This script deploys the control plane resources: DynamoDB, Cognito, Admin API, UIs (S3+CloudFront)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Deploying Shared Infrastructure" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
. "$PSScriptRoot\utils\load-config.ps1"

$STACK_NAME = "$env:DEMO_STACK_PREFIX-shared"
$SERVER_DIR = "$PSScriptRoot\..\server"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Profile: $env:AWS_PROFILE" -ForegroundColor Gray
Write-Host "  Region: $env:AWS_REGION" -ForegroundColor Gray
Write-Host "  Stack: $STACK_NAME" -ForegroundColor Gray
Write-Host "  Admin Email: $env:DEMO_ADMIN_EMAIL" -ForegroundColor Gray
Write-Host ""

# Check/Create SAM S3 Bucket
if ([string]::IsNullOrEmpty($env:SAM_S3_BUCKET)) {
    Write-Host "Creating SAM artifacts bucket..." -ForegroundColor Yellow
    
    # Generate unique bucket name
    $uuid = [guid]::NewGuid().ToString().Substring(0, 8)
    $SAM_BUCKET = "$env:DEMO_STACK_PREFIX-sam-artifacts-$uuid"
    
    Write-Host "  Bucket name: $SAM_BUCKET" -ForegroundColor Gray
    
    try {
        aws s3 mb "s3://$SAM_BUCKET" --profile $env:AWS_PROFILE --region $env:AWS_REGION
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Bucket created" -ForegroundColor Green
        } else {
            Write-Host "  Using existing bucket" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Using existing bucket" -ForegroundColor Green
    }
    
    $env:SAM_S3_BUCKET = $SAM_BUCKET
} else {
    $SAM_BUCKET = $env:SAM_S3_BUCKET
    Write-Host "Using existing SAM bucket: $SAM_BUCKET" -ForegroundColor Green
}

Write-Host ""

# Update samconfig.toml with actual values (handles both placeholders and existing values)
Write-Host "Updating shared-samconfig.toml..." -ForegroundColor Yellow
$samConfigPath = Join-Path $SERVER_DIR "shared-samconfig.toml"
$samConfig = Get-Content $samConfigPath -Raw

# Replace placeholders or existing values using regex patterns
$samConfig = $samConfig -replace 'stack_name = ".*?"', "stack_name = `"$STACK_NAME`""
$samConfig = $samConfig -replace 's3_bucket = ".*?"', "s3_bucket = `"$SAM_BUCKET`""
$samConfig = $samConfig -replace 's3_prefix = ".*?"', "s3_prefix = `"$env:DEMO_STACK_PREFIX-shared`""
$samConfig = $samConfig -replace 'region = ".*?"', "region = `"$env:AWS_REGION`""
$samConfig = $samConfig -replace 'profile = ".*?"', "profile = `"$env:AWS_PROFILE`""
$samConfig = $samConfig -replace 'StackPrefix=[^ "]*', "StackPrefix=$env:DEMO_STACK_PREFIX"

Set-Content -Path $samConfigPath -Value $samConfig
Write-Host "  Configuration updated with current values" -ForegroundColor Green
Write-Host ""

# Build the application
Write-Host "Building SAM application (this may take 5-10 minutes)..." -ForegroundColor Yellow
Push-Location $SERVER_DIR
try {
    sam build -t shared-template.yaml --use-container --profile $env:AWS_PROFILE --region $env:AWS_REGION
    
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
Write-Host "Deploying stack (this may take 15-20 minutes)..." -ForegroundColor Yellow
Write-Host "  CloudFront distributions can be slow to create" -ForegroundColor Gray
Write-Host ""

Push-Location $SERVER_DIR
try {
    sam deploy --config-file shared-samconfig.toml --profile $env:AWS_PROFILE --region $env:AWS_REGION --parameter-overrides "AdminEmailParameter=$env:DEMO_ADMIN_EMAIL StackPrefix=$env:DEMO_STACK_PREFIX"
    
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
    $outputs = aws cloudformation describe-stacks --stack-name $STACK_NAME --profile $env:AWS_PROFILE --region $env:AWS_REGION --query "Stacks[0].Outputs" --output json | ConvertFrom-Json
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " Shared Stack Outputs" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    foreach ($output in $outputs) {
        Write-Host "  $($output.OutputKey): $($output.OutputValue)" -ForegroundColor Gray
    }
    
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Save outputs to file for next scripts
    $outputsFile = "$PSScriptRoot\..\outputs-shared.json"
    $outputs | ConvertTo-Json | Set-Content $outputsFile
    Write-Host "  Outputs saved to outputs-shared.json" -ForegroundColor Green
    
} catch {
    Write-Host "  Could not retrieve stack outputs" -ForegroundColor Yellow
}

Write-Host ""

# Update .env file with SAM bucket name
if ($SAM_BUCKET) {
    Write-Host "Updating .env with SAM bucket name..." -ForegroundColor Yellow
    
    $envFile = "$PSScriptRoot\..\.env"
    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile -Raw
        
        # Update SAM_S3_BUCKET line
        if ($envContent -match "SAM_S3_BUCKET=.*") {
            $envContent = $envContent -replace "SAM_S3_BUCKET=.*", "SAM_S3_BUCKET=$SAM_BUCKET"
        } else {
            # Add if not exists
            $envContent += "`nSAM_S3_BUCKET=$SAM_BUCKET"
        }
        
        Set-Content -Path $envFile -Value $envContent -NoNewline
        Write-Host "  .env updated with: SAM_S3_BUCKET=$SAM_BUCKET" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Shared infrastructure deployment completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Check your email ($env:DEMO_ADMIN_EMAIL) for admin user password" -ForegroundColor Gray
Write-Host "  2. Run: .\scripts\02-deploy-tenant.ps1" -ForegroundColor Gray
Write-Host ""
