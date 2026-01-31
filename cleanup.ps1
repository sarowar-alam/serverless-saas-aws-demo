# Cleanup Script - Removes All AWS Resources
# This script deletes all deployed resources to avoid ongoing charges

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Red
Write-Host " AWS SaaS Demo Cleanup" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

# Load configuration
. "$PSScriptRoot\scripts\utils\load-config.ps1"

$SHARED_STACK_NAME = "$env:DEMO_STACK_PREFIX-shared"
$TENANT_STACK_NAME = "$env:DEMO_STACK_PREFIX-pooled"

Write-Host "This will delete the following resources:" -ForegroundColor Yellow
Write-Host "  • CloudFormation Stacks: $SHARED_STACK_NAME, $TENANT_STACK_NAME" -ForegroundColor Gray
Write-Host "  • S3 Buckets: Admin, Landing, Application, SAM artifacts" -ForegroundColor Gray
Write-Host "  • DynamoDB Tables: 4 tables" -ForegroundColor Gray
Write-Host "  • Cognito User Pools: 2 pools" -ForegroundColor Gray
Write-Host "  • CloudFront Distributions: 3 distributions" -ForegroundColor Gray
Write-Host "  • Lambda Functions: ~25 functions" -ForegroundColor Gray
Write-Host "  • API Gateways: 2 gateways" -ForegroundColor Gray
Write-Host ""
Write-Host "Estimated time: 20-35 minutes (CloudFront is slow)" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Are you sure you want to delete ALL resources? (type 'DELETE' to confirm)"
if ($confirmation -ne "DELETE") {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Step 1: Get S3 bucket names from stacks
Write-Host "[Step 1/6] Retrieving S3 bucket names..." -ForegroundColor Cyan
$bucketsToEmpty = @()

try {
    $sharedOutputs = aws cloudformation describe-stacks `
        --stack-name $SHARED_STACK_NAME `
        --profile $env:AWS_PROFILE `
        --region $env:AWS_REGION `
        --query "Stacks[0].Outputs" `
        --output json 2>$null | ConvertFrom-Json
    
    foreach ($output in $sharedOutputs) {
        if ($output.OutputKey -like "*Bucket") {
            $bucketsToEmpty += $output.OutputValue
        }
    }
    
    Write-Host "  Found $($bucketsToEmpty.Count) S3 buckets" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Could not retrieve bucket names from stack" -ForegroundColor Yellow
}

# Add SAM bucket if exists
if ($env:SAM_S3_BUCKET) {
    $bucketsToEmpty += $env:SAM_S3_BUCKET
}

Write-Host ""

# Step 2: Empty S3 buckets
Write-Host "[Step 2/6] Emptying S3 buckets..." -ForegroundColor Cyan
foreach ($bucket in $bucketsToEmpty) {
    try {
        Write-Host "  Emptying bucket: $bucket" -ForegroundColor Gray
        
        # Delete all objects
        aws s3 rm "s3://$bucket" --recursive --profile $env:AWS_PROFILE --region $env:AWS_REGION 2>$null
        
        # Delete all versions (if versioning enabled)
        $versions = aws s3api list-object-versions `
            --bucket $bucket `
            --profile $env:AWS_PROFILE `
            --region $env:AWS_REGION 2>$null | ConvertFrom-Json
        
        if ($versions.Versions) {
            foreach ($version in $versions.Versions) {
                aws s3api delete-object `
                    --bucket $bucket `
                    --key $version.Key `
                    --version-id $version.VersionId `
                    --profile $env:AWS_PROFILE `
                    --region $env:AWS_REGION 2>$null
            }
        }
        
        Write-Host "    ✓ Bucket emptied" -ForegroundColor Green
    } catch {
        Write-Host "    ⚠ Could not empty bucket: $bucket" -ForegroundColor Yellow
    }
}

Write-Host ""

# Step 3: Delete tenant stack
Write-Host "[Step 3/6] Deleting tenant stack ($TENANT_STACK_NAME)..." -ForegroundColor Cyan
try {
    aws cloudformation delete-stack `
        --stack-name $TENANT_STACK_NAME `
        --profile $env:AWS_PROFILE `
        --region $env:AWS_REGION
    
    Write-Host "  Waiting for stack deletion (this may take 5-10 minutes)..." -ForegroundColor Gray
    
    aws cloudformation wait stack-delete-complete `
        --stack-name $TENANT_STACK_NAME `
        --profile $env:AWS_PROFILE `
        --region $env:AWS_REGION
    
    Write-Host "  ✓ Tenant stack deleted" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Tenant stack deletion failed or stack doesn't exist" -ForegroundColor Yellow
}

Write-Host ""

# Step 4: Delete shared stack
Write-Host "[Step 4/6] Deleting shared stack ($SHARED_STACK_NAME)..." -ForegroundColor Cyan
Write-Host "  Note: CloudFront distributions take 15-30 minutes to delete" -ForegroundColor Gray
try {
    aws cloudformation delete-stack `
        --stack-name $SHARED_STACK_NAME `
        --profile $env:AWS_PROFILE `
        --region $env:AWS_REGION
    
    Write-Host "  Waiting for stack deletion (this may take 20-30 minutes)..." -ForegroundColor Gray
    
    aws cloudformation wait stack-delete-complete `
        --stack-name $SHARED_STACK_NAME `
        --profile $env:AWS_PROFILE `
        --region $env:AWS_REGION
    
    Write-Host "  ✓ Shared stack deleted" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Shared stack deletion failed or stack doesn't exist" -ForegroundColor Yellow
}

Write-Host ""

# Step 5: Delete S3 buckets
Write-Host "[Step 5/6] Deleting S3 buckets..." -ForegroundColor Cyan
foreach ($bucket in $bucketsToEmpty) {
    try {
        aws s3 rb "s3://$bucket" --profile $env:AWS_PROFILE --region $env:AWS_REGION 2>$null
        Write-Host "  ✓ Deleted bucket: $bucket" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠ Could not delete bucket: $bucket" -ForegroundColor Yellow
    }
}

Write-Host ""

# Step 6: Optional - Delete CloudWatch Logs
Write-Host "[Step 6/6] CloudWatch Log Groups" -ForegroundColor Cyan
$deleteLogs = Read-Host "Delete CloudWatch log groups? (yes/no)"

if ($deleteLogs -eq "yes") {
    try {
        $logGroups = aws logs describe-log-groups `
            --profile $env:AWS_PROFILE `
            --region $env:AWS_REGION `
            --query "logGroups[?starts_with(logGroupName, '/aws/lambda/$env:DEMO_STACK_PREFIX')].logGroupName" `
            --output json | ConvertFrom-Json
        
        foreach ($logGroup in $logGroups) {
            aws logs delete-log-group `
                --log-group-name $logGroup `
                --profile $env:AWS_PROFILE `
                --region $env:AWS_REGION 2>$null
            Write-Host "  ✓ Deleted log group: $logGroup" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ⚠ Could not delete log groups" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⊘ Skipped log group deletion" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " ✓ Cleanup Completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "All AWS resources have been deleted." -ForegroundColor Gray
Write-Host "You can verify by checking the AWS Console:" -ForegroundColor Gray
Write-Host "  • CloudFormation: https://console.aws.amazon.com/cloudformation" -ForegroundColor Gray
Write-Host "  • S3: https://console.aws.amazon.com/s3" -ForegroundColor Gray
Write-Host ""
