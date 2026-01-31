# Cleanup Script - Delete all DEMO resources from AWS
# WARNING: This will permanently delete all resources!

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Red
Write-Host " AWS DEMO Cleanup Script" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "This will DELETE all resources deployed by the DEMO!" -ForegroundColor Yellow
Write-Host ""
$confirmation = Read-Host "Are you sure you want to continue? (yes/no)"

if ($confirmation -ne "yes") {
    Write-Host "Cleanup cancelled." -ForegroundColor Green
    exit 0
}

# Load configuration
. "$PSScriptRoot\utils\load-config.ps1"

$SHARED_STACK = "$env:DEMO_STACK_PREFIX-shared"
$TENANT_STACK = "$env:DEMO_STACK_PREFIX-pooled"

Write-Host ""
Write-Host "Step 1: Deleting Tenant Stack..." -ForegroundColor Yellow
try {
    aws cloudformation delete-stack --stack-name $TENANT_STACK --profile $env:AWS_PROFILE --region $env:AWS_REGION
    Write-Host "  Waiting for stack deletion..." -ForegroundColor Gray
    aws cloudformation wait stack-delete-complete --stack-name $TENANT_STACK --profile $env:AWS_PROFILE --region $env:AWS_REGION
    Write-Host "  Tenant stack deleted" -ForegroundColor Green
} catch {
    Write-Host "  Stack does not exist or already deleted" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Step 2: Emptying and deleting S3 buckets..." -ForegroundColor Yellow

# Get bucket names from shared stack (before deleting it)
try {
    $outputsJson = aws cloudformation describe-stacks --stack-name $SHARED_STACK --profile $env:AWS_PROFILE --region $env:AWS_REGION --output json 2>$null
    if ($outputsJson) {
        $stack = $outputsJson | ConvertFrom-Json
        $bucketOutputs = $stack.Stacks[0].Outputs | Where-Object { $_.OutputKey -like "*Bucket*" }
        
        foreach ($output in $bucketOutputs) {
            $bucket = $output.OutputValue
            if ($bucket) {
                Write-Host "  Emptying bucket: $bucket" -ForegroundColor Gray
                aws s3 rm "s3://$bucket" --recursive --profile $env:AWS_PROFILE --region $env:AWS_REGION 2>$null
                Write-Host "  Bucket emptied: $bucket" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Host "  Could not retrieve buckets" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Step 3: Deleting Shared Stack..." -ForegroundColor Yellow
try {
    aws cloudformation delete-stack --stack-name $SHARED_STACK --profile $env:AWS_PROFILE --region $env:AWS_REGION
    Write-Host "  Waiting for stack deletion (this may take 5-10 minutes)..." -ForegroundColor Gray
    aws cloudformation wait stack-delete-complete --stack-name $SHARED_STACK --profile $env:AWS_PROFILE --region $env:AWS_REGION
    Write-Host "  Shared stack deleted" -ForegroundColor Green
} catch {
    Write-Host "  Stack does not exist or already deleted" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Step 4: Deleting SAM artifacts bucket..." -ForegroundColor Yellow
if ($env:SAM_S3_BUCKET) {
    try {
        Write-Host "  Emptying SAM bucket: $env:SAM_S3_BUCKET" -ForegroundColor Gray
        aws s3 rm "s3://$env:SAM_S3_BUCKET" --recursive --profile $env:AWS_PROFILE --region $env:AWS_REGION 2>$null
        aws s3 rb "s3://$env:SAM_S3_BUCKET" --profile $env:AWS_PROFILE --region $env:AWS_REGION
        Write-Host "  SAM bucket deleted" -ForegroundColor Green
    } catch {
        Write-Host "  SAM bucket does not exist or already deleted" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Step 5: Deleting CloudWatch Log Groups..." -ForegroundColor Yellow
try {
    $logGroupsJson = aws logs describe-log-groups --profile $env:AWS_PROFILE --region $env:AWS_REGION --output json 2>$null
    if ($logGroupsJson) {
        $allLogGroups = $logGroupsJson | ConvertFrom-Json
        $matchingLogGroups = $allLogGroups.logGroups | Where-Object { $_.logGroupName -like "*$env:DEMO_STACK_PREFIX*" }
        
        foreach ($logGroup in $matchingLogGroups) {
            $logGroupName = $logGroup.logGroupName
            if ($logGroupName) {
                Write-Host "  Deleting log group: $logGroupName" -ForegroundColor Gray
                aws logs delete-log-group --log-group-name $logGroupName --profile $env:AWS_PROFILE --region $env:AWS_REGION 2>$null
                Write-Host "  Log group deleted" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Host "  No log groups found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Cleanup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "All AWS resources have been deleted." -ForegroundColor Green
Write-Host ""
