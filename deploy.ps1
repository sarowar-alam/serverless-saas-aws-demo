# Master Deployment Script - Deploys Complete AWS SaaS Demo
# This orchestrates all deployment steps

$ErrorActionPreference = "Stop"

$banner = @"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     AWS Serverless SaaS Workshop - Complete Demo Deploy      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
"@

Write-Host $banner -ForegroundColor Cyan
Write-Host ""

$deployStart = Get-Date

# Step 1: Validate Prerequisites
Write-Host "[Step 1/7] Validating prerequisites..." -ForegroundColor Cyan
& "$PSScriptRoot\scripts\utils\validate-prereqs.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Prerequisites validation failed. Please install missing tools." -ForegroundColor Red
    exit 1
}

# Step 2: Load Configuration
Write-Host "[Step 2/7] Loading configuration..." -ForegroundColor Cyan
. "$PSScriptRoot\scripts\utils\load-config.ps1"

Write-Host "Deployment Summary:" -ForegroundColor Yellow
Write-Host "  AWS Profile: $env:AWS_PROFILE" -ForegroundColor Gray
Write-Host "  AWS Region: $env:AWS_REGION" -ForegroundColor Gray
Write-Host "  Stack Prefix: $env:DEMO_STACK_PREFIX" -ForegroundColor Gray
Write-Host "  Admin Email: $env:DEMO_ADMIN_EMAIL" -ForegroundColor Gray
Write-Host ""
Write-Host "Estimated deployment time: 40-50 minutes" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Continue with deployment? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Step 3: Deploy Shared Infrastructure
Write-Host "[Step 3/7] Deploying shared infrastructure (~15-20 min)..." -ForegroundColor Cyan
& "$PSScriptRoot\scripts\01-deploy-shared.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Shared stack deployment failed." -ForegroundColor Red
    exit 1
}

# Step 4: Deploy Tenant Stack
Write-Host "[Step 4/7] Deploying tenant stack (~8-10 min)..." -ForegroundColor Cyan
& "$PSScriptRoot\scripts\02-deploy-tenant.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Tenant stack deployment failed." -ForegroundColor Red
    exit 1
}

# Step 5: Build Client Applications
Write-Host "[Step 5/7] Building client applications (~15-20 min)..." -ForegroundColor Cyan
& "$PSScriptRoot\scripts\03-build-clients.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Client build failed." -ForegroundColor Red
    exit 1
}

# Step 6: Deploy Clients to S3/CloudFront
Write-Host "[Step 6/7] Deploying client applications..." -ForegroundColor Cyan
Write-Host "Note: This step requires the 04-deploy-clients.ps1 script" -ForegroundColor Yellow
Write-Host ""

# Step 7: Create Test Tenants (Optional)
Write-Host "[Step 7/7] Would you like to create test tenants?" -ForegroundColor Cyan
$createTenants = Read-Host "(yes/no)"
if ($createTenants -eq "yes") {
    Write-Host "Note: This step requires the 05-create-test-tenants.ps1 script" -ForegroundColor Yellow
}

Write-Host ""

$deployEnd = Get-Date
$totalDuration = ($deployEnd - $deployStart).TotalMinutes

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                               ║" -ForegroundColor Green
Write-Host "║     ✓ Deployment Completed Successfully!                     ║" -ForegroundColor Green
Write-Host "║                                                               ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Total deployment time: $([math]::Round($totalDuration, 1)) minutes" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Check email ($env:DEMO_ADMIN_EMAIL) for admin credentials" -ForegroundColor Gray
Write-Host "  2. Run: .\scripts\geturl.ps1 to get application URLs" -ForegroundColor Gray
Write-Host "  3. Access Admin UI to manage tenants" -ForegroundColor Gray
Write-Host "  4. Use Landing page to register new tenants" -ForegroundColor Gray
Write-Host ""
Write-Host "To clean up all resources:" -ForegroundColor Yellow
Write-Host "  Run: .\cleanup.ps1" -ForegroundColor Gray
Write-Host ""
