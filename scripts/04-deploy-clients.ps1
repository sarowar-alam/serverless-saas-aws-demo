# Deploy Client Applications to S3
# This script uploads the built Angular applications to their respective S3 buckets

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Deploying Client Applications to S3" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
. "$PSScriptRoot\utils\load-config.ps1"

$SHARED_STACK_NAME = "$env:DEMO_STACK_PREFIX-shared"
$CLIENT_DIR = "$PSScriptRoot\..\client"

# Get S3 bucket names from shared stack
Write-Host "Retrieving S3 bucket names..." -ForegroundColor Yellow
try {
    $sharedOutputs = aws cloudformation describe-stacks --stack-name $SHARED_STACK_NAME --profile $env:AWS_PROFILE --region $env:AWS_REGION --query "Stacks[0].Outputs" --output json | ConvertFrom-Json
    
    $ADMIN_BUCKET = ($sharedOutputs | Where-Object { $_.OutputKey -eq "AdminSiteBucket" }).OutputValue
    $LANDING_BUCKET = ($sharedOutputs | Where-Object { $_.OutputKey -eq "LandingApplicationSiteBucket" }).OutputValue
    $APP_BUCKET = ($sharedOutputs | Where-Object { $_.OutputKey -eq "ApplicationSiteBucket" }).OutputValue
    $ADMIN_CLOUDFRONT = ($sharedOutputs | Where-Object { $_.OutputKey -eq "AdminAppSite" }).OutputValue
    $LANDING_CLOUDFRONT = ($sharedOutputs | Where-Object { $_.OutputKey -eq "LandingApplicationSite" }).OutputValue
    $APP_CLOUDFRONT = ($sharedOutputs | Where-Object { $_.OutputKey -eq "ApplicationSite" }).OutputValue
    
    Write-Host "  Admin Bucket: $ADMIN_BUCKET" -ForegroundColor Green
    Write-Host "  Landing Bucket: $LANDING_BUCKET" -ForegroundColor Green
    Write-Host "  Application Bucket: $APP_BUCKET" -ForegroundColor Green
    
} catch {
    Write-Host "  Failed to retrieve bucket names" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Deploy Admin UI
Write-Host "Deploying Admin UI..." -ForegroundColor Yellow
$adminDist = Join-Path $CLIENT_DIR "Admin\dist"
if (Test-Path $adminDist) {
    aws s3 sync $adminDist "s3://$ADMIN_BUCKET" --delete --profile $env:AWS_PROFILE
    Write-Host "  Admin UI deployed" -ForegroundColor Green
} else {
    Write-Host "  Admin dist folder not found - run build first" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Deploy Landing UI
Write-Host "Deploying Landing UI..." -ForegroundColor Yellow
$landingDist = Join-Path $CLIENT_DIR "Landing\dist"
if (Test-Path $landingDist) {
    aws s3 sync $landingDist "s3://$LANDING_BUCKET" --delete --profile $env:AWS_PROFILE
    Write-Host "  Landing UI deployed" -ForegroundColor Green
} else {
    Write-Host "  Landing dist folder not found - run build first" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Deploy Application UI
Write-Host "Deploying Application UI..." -ForegroundColor Yellow
$appDist = Join-Path $CLIENT_DIR "Application\dist"
if (Test-Path $appDist) {
    aws s3 sync $appDist "s3://$APP_BUCKET" --delete --profile $env:AWS_PROFILE
    Write-Host "  Application UI deployed" -ForegroundColor Green
} else {
    Write-Host "  Application dist folder not found - run build first" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " All UIs deployed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "CloudFront URLs (may take 5-10 mins to update cache):" -ForegroundColor Yellow
Write-Host "  Admin: https://$ADMIN_CLOUDFRONT" -ForegroundColor Gray
Write-Host "  Landing: https://$LANDING_CLOUDFRONT" -ForegroundColor Gray
Write-Host "  Application: https://$APP_CLOUDFRONT" -ForegroundColor Gray
Write-Host ""
Write-Host "To invalidate CloudFront cache for immediate update, run:" -ForegroundColor Yellow
Write-Host "  aws cloudfront create-invalidation --distribution-id <ID> --paths '/*'" -ForegroundColor Gray
Write-Host ""
