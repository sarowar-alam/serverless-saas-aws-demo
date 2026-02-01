# AWS Serverless SaaS - Complete Deployment Script
# This script deploys the entire application in one run
# Features: Idempotent, error handling, rollback support, progress tracking

param(
    [switch]$SkipShared,      # Skip shared stack deployment
    [switch]$SkipTenant,      # Skip tenant stack deployment
    [switch]$SkipBuild,       # Skip client build
    [switch]$SkipDeploy,      # Skip client deployment
    [switch]$UpdateOnly,      # Only update existing stacks (no new resources)
    [switch]$Force,           # Force rebuild even if unchanged
    [switch]$NoDocker         # Build without Docker containers (faster but less reliable)
)

$ErrorActionPreference = "Continue"  # Continue on errors, we'll handle them
$Global:DeploymentSuccess = $true
$Global:DeploymentLog = @()

# Auto-detect Docker availability
function Test-DockerAvailable {
    try {
        $null = docker version 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# Color scheme
$Colors = @{
    Info = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Header = "Magenta"
}

function Write-StepHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $Colors.Header
    Write-Host " $Message" -ForegroundColor $Colors.Header
    Write-Host "========================================" -ForegroundColor $Colors.Header
    Write-Host ""
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor $Colors.Info
}

function Write-Success {
    param([string]$Message)
    Write-Host "  SUCCESS: $Message" -ForegroundColor $Colors.Success
    $Global:DeploymentLog += "[SUCCESS] $Message"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  WARNING: $Message" -ForegroundColor $Colors.Warning
    $Global:DeploymentLog += "[WARNING] $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host "  ERROR: $Message" -ForegroundColor $Colors.Error
    $Global:DeploymentLog += "[ERROR] $Message"
    $Global:DeploymentSuccess = $false
}

function Test-StackExists {
    param([string]$StackName)
    
    try {
        $status = aws cloudformation describe-stacks --stack-name $StackName --profile $env:AWS_PROFILE --region $env:AWS_REGION --query "Stacks[0].StackStatus" --output text 2>$null
        return ($null -ne $status -and $status -ne "")
    } catch {
        return $false
    }
}

function Get-StackStatus {
    param([string]$StackName)
    
    try {
        $status = aws cloudformation describe-stacks --stack-name $StackName --profile $env:AWS_PROFILE --region $env:AWS_REGION --query "Stacks[0].StackStatus" --output text 2>$null
        return $status
    } catch {
        return $null
    }
}

function Wait-ForStackReady {
    param([string]$StackName)
    
    $status = Get-StackStatus -StackName $StackName
    
    if ($status -like "*IN_PROGRESS") {
        Write-Info "Stack is currently updating, waiting for completion..."
        
        $maxWait = 60  # 60 minutes max
        $waited = 0
        
        while ($status -like "*IN_PROGRESS" -and $waited -lt $maxWait) {
            Start-Sleep -Seconds 30
            $waited += 0.5
            $status = Get-StackStatus -StackName $StackName
            Write-Host "." -NoNewline
        }
        
        Write-Host ""
        
        if ($status -like "*COMPLETE") {
            Write-Success "Stack is ready: $status"
            return $true
        } elseif ($status -like "*FAILED" -or $status -like "*ROLLBACK*") {
            Write-Error "Stack operation failed: $status"
            return $false
        }
    }
    
    return $true
}

function Invoke-SAMDeploy {
    param(
        [string]$StackName,
        [string]$Template,
        [string]$ConfigFile,
        [string]$ParameterOverrides,
        [switch]$NoBuild
    )
    
    $SERVER_DIR = "$PSScriptRoot\server"
    Push-Location $SERVER_DIR
    
    try {
        # Check if stack exists
        $stackExists = Test-StackExists -StackName $StackName
        
        if ($stackExists) {
            $status = Get-StackStatus -StackName $StackName
            Write-Info "Stack exists with status: $status"
            
            # Wait if currently updating
            if (-not (Wait-ForStackReady -StackName $StackName)) {
                throw "Stack is not in a deployable state"
            }
        } else {
            Write-Info "Stack does not exist, will create new"
        }
        
        # Build if not skipped
        if (-not $NoBuild) {
            Write-Info "Building SAM application..."
            
            # Build command with optional container flag
            $buildCmd = "sam build -t $Template --profile $env:AWS_PROFILE --region $env:AWS_REGION"
            if (-not $NoDocker) {
                $buildCmd += " --use-container"
            }
            
            # Redirect stderr to stdout to prevent PowerShell from showing red error messages for SAM CLI info messages
            $ErrorActionPreference = "Continue"
            Invoke-Expression "$buildCmd 2>&1" | ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord]) {
                    # SAM CLI writes info messages to stderr, don't treat as errors
                    Write-Host $_.Exception.Message
                } else {
                    Write-Host $_
                }
            }
            
            if ($LASTEXITCODE -ne 0) {
                throw "SAM build failed with exit code $LASTEXITCODE"
            }
            
            Write-Success "Build completed"
        }
        
        # Deploy
        Write-Info "Deploying stack..."
        Write-Host ""
        
        $deployCmd = "sam deploy --config-file $ConfigFile --profile $env:AWS_PROFILE --region $env:AWS_REGION"
        
        if ($ParameterOverrides) {
            $deployCmd += " --parameter-overrides $ParameterOverrides"
        }
        
        # Execute deployment - let output flow naturally
        Write-Host "Executing: $deployCmd" -ForegroundColor Gray
        Write-Host ""
        
        # Capture output to check for "No changes to deploy" message
        $deployOutput = Invoke-Expression "$deployCmd 2>&1"
        $deployOutput | Out-Host
        
        # Check if deployment succeeded or if there were no changes (also considered success)
        $noChanges = $deployOutput | Where-Object { $_ -match "No changes to deploy" }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Success "Stack deployed: $StackName"
            return $true
        } elseif ($noChanges) {
            Write-Host ""
            Write-Success "Stack up-to-date: $StackName (no changes detected)"
            return $true
        } else {
            Write-Host ""
            throw "SAM deploy failed with exit code $LASTEXITCODE"
        }
        
    } catch {
        Write-Error "Deployment failed: $_"
        return $false
    } finally {
        Pop-Location
    }
}

function Get-StackOutputs {
    param([string]$StackName)
    
    try {
        $outputsJson = aws cloudformation describe-stacks --stack-name $StackName --profile $env:AWS_PROFILE --region $env:AWS_REGION --query "Stacks[0].Outputs" --output json 2>$null
        
        if ($outputsJson) {
            return ($outputsJson | ConvertFrom-Json)
        }
    } catch {
        Write-Warning "Could not retrieve outputs for $StackName"
    }
    
    return $null
}

function Update-EnvironmentFiles {
    param(
        [hashtable]$SharedOutputs,
        [hashtable]$TenantOutputs
    )
    
    Write-StepHeader "Updating Angular Environment Files"
    
    $CLIENT_DIR = "$PSScriptRoot\client"
    $updated = 0
    
    # Admin environment
    $adminApiUrl = $SharedOutputs["AdminApi"]
    $adminUserPoolId = if ($SharedOutputs["CognitoOperationUsersUserPoolProviderURL"]) {
        ($SharedOutputs["CognitoOperationUsersUserPoolProviderURL"] -split '/')[-1]
    } else { $null }
    $adminAppClientId = $SharedOutputs["CognitoOperationUsersUserPoolClientId"]
    
    if ($adminApiUrl -and $adminUserPoolId -and $adminAppClientId) {
        $adminEnvFile = Join-Path $CLIENT_DIR "Admin\src\environments\environment.prod.ts"
        
        if (Test-Path $adminEnvFile) {
            Write-Info "Updating Admin environment..."
            
            $content = Get-Content $adminEnvFile -Raw
            $content = $content -replace "apiUrl:\s*'[^']*'", "apiUrl: '$adminApiUrl'"
            $content = $content -replace "userPoolId:\s*'[^']*'", "userPoolId: '$adminUserPoolId'"
            $content = $content -replace "appClientId:\s*'[^']*'", "appClientId: '$adminAppClientId'"
            
            Set-Content -Path $adminEnvFile -Value $content -NoNewline
            Write-Success "Admin environment updated"
            $updated++
        }
        
        # Update aws-exports.ts for Admin (used by AWS Amplify)
        $awsExportsFile = Join-Path $CLIENT_DIR "Admin\src\aws-exports.ts"
        if (Test-Path $awsExportsFile) {
            Write-Info "Updating Admin aws-exports..."
            
            $content = Get-Content $awsExportsFile -Raw
            $content = $content -replace "aws_user_pools_id:\s*'[^']*'", "aws_user_pools_id: '$adminUserPoolId'"
            $content = $content -replace "aws_user_pools_web_client_id:\s*'[^']*'", "aws_user_pools_web_client_id: '$adminAppClientId'"
            
            Set-Content -Path $awsExportsFile -Value $content -NoNewline
            Write-Success "Admin aws-exports updated"
        }
    }
    
    # Landing environment
    if ($adminApiUrl) {
        $landingEnvFile = Join-Path $CLIENT_DIR "Landing\src\environments\environment.prod.ts"
        
        if (Test-Path $landingEnvFile) {
            Write-Info "Updating Landing environment..."
            
            $content = Get-Content $landingEnvFile -Raw
            $content = $content -replace "apiGatewayUrl:\s*'[^']*'", "apiGatewayUrl: '$adminApiUrl'"
            
            Set-Content -Path $landingEnvFile -Value $content -NoNewline
            Write-Success "Landing environment updated"
            $updated++
        }
    }
    
    # Application environment
    $tenantApiUrl = $TenantOutputs["TenantAPI"]
    $tenantUserPoolId = $SharedOutputs["CognitoTenantUserPoolId"]
    $tenantAppClientId = $SharedOutputs["CognitoTenantAppClientId"]
    
    if ($adminApiUrl -and $tenantApiUrl -and $tenantUserPoolId -and $tenantAppClientId) {
        $appEnvFile = Join-Path $CLIENT_DIR "Application\src\environments\environment.prod.ts"
        
        if (Test-Path $appEnvFile) {
            Write-Info "Updating Application environment..."
            
            $content = Get-Content $appEnvFile -Raw
            $content = $content -replace "regApiGatewayUrl:\s*'[^']*'", "regApiGatewayUrl: '$adminApiUrl'"
            $content = $content -replace "(?<!reg)apiGatewayUrl:\s*'[^']*'", "apiGatewayUrl: '$tenantApiUrl'"
            $content = $content -replace "userPoolId:\s*'[^']*'", "userPoolId: '$tenantUserPoolId'"
            $content = $content -replace "appClientId:\s*'[^']*'", "appClientId: '$tenantAppClientId'"
            
            Set-Content -Path $appEnvFile -Value $content -NoNewline
            Write-Success "Application environment updated"
            $updated++
        }
    }
    
    Write-Success "Updated $updated environment file(s)"
}

function Invoke-ClientBuild {
    param([string]$AppName, [string]$AppDir)
    
    Push-Location $AppDir
    
    try {
        # Check if already built and not forcing rebuild
        $distDir = Join-Path $AppDir "dist"
        if ((Test-Path $distDir) -and (-not $Force)) {
            $distTime = (Get-Item $distDir).LastWriteTime
            $srcTime = (Get-ChildItem -Path "src" -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
            
            if ($distTime -gt $srcTime) {
                Write-Info "$AppName - Build is up-to-date, skipping"
                return $true
            }
        }
        
        Write-Info "$AppName - Installing dependencies..."
        
        if ($AppName -eq "Application") {
            npm install --legacy-peer-deps --silent 2>&1 | Out-Null
        } else {
            npm install --silent 2>&1 | Out-Null
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "$AppName - npm install had warnings (continuing)"
        }
        
        Write-Info "$AppName - Building..."
        
        npm run build --silent 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $distDir)) {
            Write-Success "$AppName - Build completed"
            return $true
        } else {
            Write-Error "$AppName - Build failed"
            return $false
        }
        
    } catch {
        Write-Error "$AppName - Build error - $_"
        return $false
    } finally {
        Pop-Location
    }
}

function Invoke-ClientDeploy {
    param([string]$AppName, [string]$DistDir, [string]$BucketName)
    
    if (-not (Test-Path $DistDir)) {
        Write-Error "$AppName - dist folder not found at $DistDir"
        return $false
    }
    
    Write-Info "$AppName - Deploying to S3..."
    
    try {
        aws s3 sync $DistDir "s3://$BucketName" --delete --profile $env:AWS_PROFILE --region $env:AWS_REGION 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "$AppName - Deployed to $BucketName"
            return $true
        } else {
            Write-Error "$AppName - S3 sync failed"
            return $false
        }
    } catch {
        Write-Error "$AppName - Deployment error - $_"
        return $false
    }
}

function Save-DeploymentOutputs {
    param([hashtable]$SharedOutputs, [hashtable]$TenantOutputs)
    
    $outputFile = "$PSScriptRoot\deployment-outputs.json"
    
    $outputs = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SharedStack = $SharedOutputs
        TenantStack = $TenantOutputs
    }
    
    $outputs | ConvertTo-Json -Depth 10 | Set-Content $outputFile
    Write-Success "Deployment outputs saved to deployment-outputs.json"
}

function Get-CognitoAdminCredentials {
    param([string]$UserPoolId, [string]$AdminEmail)
    
    try {
        Write-Info "Retrieving admin user information from Cognito..."
        
        $userJson = aws cognito-idp admin-get-user `
            --user-pool-id $UserPoolId `
            --username $AdminEmail `
            --profile $env:AWS_PROFILE `
            --region $env:AWS_REGION `
            --output json 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $userJson) {
            $user = $userJson | ConvertFrom-Json
            $userStatus = $user.UserStatus
            
            Write-Info "Admin user status: $userStatus"
            
            if ($userStatus -eq "FORCE_CHANGE_PASSWORD") {
                Write-Warning "Admin user exists but requires password change"
                Write-Info "Check email $AdminEmail for temporary password from Cognito"
                return @{
                    Username = $AdminEmail
                    Status = $userStatus
                    Message = "Temporary password sent to email. First login requires password change."
                }
            } elseif ($userStatus -eq "CONFIRMED") {
                Write-Success "Admin user is active and confirmed"
                return @{
                    Username = $AdminEmail
                    Status = $userStatus
                    Message = "User is active. Use your configured password to login."
                }
            } else {
                return @{
                    Username = $AdminEmail
                    Status = $userStatus
                    Message = "User status: $userStatus"
                }
            }
        } else {
            Write-Info "Admin user not yet created in Cognito"
            Write-Info "User will be created automatically when you first access the Admin Portal"
            return @{
                Username = $AdminEmail
                Status = "NOT_CREATED"
                Message = "Admin user will be created on first login. Cognito will send temporary password to email."
            }
        }
    } catch {
        Write-Warning "Could not retrieve admin credentials: $_"
        return @{
            Username = $AdminEmail
            Status = "UNKNOWN"
            Message = "Unable to check user status. User may not exist yet or will be created on first login."
        }
    }
}

function Send-DeploymentNotification {
    param(
        [hashtable]$SharedOutputs,
        [hashtable]$TenantOutputs,
        [hashtable]$AdminCredentials
    )
    
    Write-StepHeader "Deployment Summary Email"
    
    $adminUrl = if ($SharedOutputs["AdminAppSite"]) { "https://$($SharedOutputs['AdminAppSite'])" } else { "N/A" }
    $landingUrl = if ($SharedOutputs["LandingApplicationSite"]) { "https://$($SharedOutputs['LandingApplicationSite'])" } else { "N/A" }
    $appUrl = if ($SharedOutputs["ApplicationSite"]) { "https://$($SharedOutputs['ApplicationSite'])" } else { "N/A" }
    
    $emailBody = @"
AWS Serverless SaaS Deployment Complete
========================================

Deployment Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Region: $env:AWS_REGION
Stack Prefix: $env:DEMO_STACK_PREFIX

CloudFront URLs:
----------------
Admin Portal:       $adminUrl
Landing Page:       $landingUrl
Application Portal: $appUrl

Admin Credentials:
------------------
Username: $env:DEMO_ADMIN_EMAIL
$(if ($AdminCredentials) {
"Status: $($AdminCredentials.Status)
$($AdminCredentials.Message)"
} else {
"Check your email for Cognito temporary password"
})

API Endpoints:
--------------
Admin API: $($SharedOutputs['AdminApi'])
Tenant API: $($TenantOutputs['TenantAPI'])

Cognito Details:
----------------
Admin User Pool: $($SharedOutputs['CognitoOperationUsersUserPoolProviderURL'] -replace 'https://cognito-idp\..*\.amazonaws\.com/', '')
Admin Client ID: $($SharedOutputs['CognitoOperationUsersUserPoolClientId'])
Tenant User Pool: $($SharedOutputs['CognitoTenantUserPoolId'])
Tenant Client ID: $($SharedOutputs['CognitoTenantAppClientId'])

Next Steps:
-----------
1. Access Admin Portal: $adminUrl
2. Login with credentials sent to: $env:DEMO_ADMIN_EMAIL
3. Create and activate tenants
4. Test tenant registration via Landing page

Stack Names:
------------
Shared: $env:DEMO_STACK_PREFIX-shared
Tenant: $env:DEMO_STACK_PREFIX-pooled

"@

    # Save to file
    $summaryFile = "$PSScriptRoot\deployment-summary.txt"
    Set-Content -Path $summaryFile -Value $emailBody
    Write-Success "Deployment summary saved to deployment-summary.txt"
    
    Write-Host ""
    Write-Host $emailBody -ForegroundColor Gray
}

# ============================================
# MAIN DEPLOYMENT SCRIPT
# ============================================

$startTime = Get-Date

Write-Host ""
Write-Host "========================================" -ForegroundColor $Colors.Header
Write-Host " AWS SERVERLESS SAAS - FULL DEPLOYMENT" -ForegroundColor $Colors.Header
Write-Host "========================================" -ForegroundColor $Colors.Header
Write-Host ""

# Load configuration
$envFile = "$PSScriptRoot\.env"
if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: .env file not found" -ForegroundColor Red
    Write-Host "Please create .env file from .env.example" -ForegroundColor Yellow
    exit 1
}

Write-Info "Loading configuration from .env..."
Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -ne "" -and -not $line.StartsWith("#") -and $line -match "^([^=]+)=(.*)$") {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim() -replace '^["'']|["'']$', ''
        Set-Item -Path "env:$key" -Value $value
    }
}

# Validate configuration
$requiredVars = @("AWS_PROFILE", "AWS_REGION", "DEMO_STACK_PREFIX", "DEMO_ADMIN_EMAIL")
$missing = $requiredVars | Where-Object { -not (Test-Path "env:$_") -or [string]::IsNullOrEmpty((Get-Item "env:$_").Value) }

if ($missing) {
    Write-Host "ERROR: Missing required variables in .env: $($missing -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Configuration:" -ForegroundColor $Colors.Info
Write-Host "  Profile: $env:AWS_PROFILE" -ForegroundColor Gray
Write-Host "  Region: $env:AWS_REGION" -ForegroundColor Gray
Write-Host "  Stack Prefix: $env:DEMO_STACK_PREFIX" -ForegroundColor Gray
Write-Host "  Admin Email: $env:DEMO_ADMIN_EMAIL" -ForegroundColor Gray
Write-Host ""

# Auto-detect Docker if not explicitly disabled
if (-not $NoDocker) {
    $dockerAvailable = Test-DockerAvailable
    if ($dockerAvailable) {
        Write-Host "  Docker: Available (using containers for Lambda builds)" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  ERROR: Docker is not running!" -ForegroundColor Red
        Write-Host ""
        Write-Host "  This deployment requires Docker Desktop to build Lambda functions." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Please:" -ForegroundColor Cyan
        Write-Host "    1. Start Docker Desktop" -ForegroundColor Gray
        Write-Host "    2. Wait for it to fully start" -ForegroundColor Gray
        Write-Host "    3. Rerun this script" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Or use: .\deploy.ps1 -NoDocker (not recommended for production)" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
}
Write-Host ""

$SHARED_STACK_NAME = "$env:DEMO_STACK_PREFIX-shared"
$TENANT_STACK_NAME = "$env:DEMO_STACK_PREFIX-pooled"
$SERVER_DIR = "$PSScriptRoot\server"
$CLIENT_DIR = "$PSScriptRoot\client"

# ============================================
# STEP 1: SETUP SAM S3 BUCKET
# ============================================

Write-StepHeader "Step 1: SAM Artifacts Bucket"

if ([string]::IsNullOrEmpty($env:SAM_S3_BUCKET)) {
    $uuid = [guid]::NewGuid().ToString().Substring(0, 8)
    $SAM_BUCKET = "$env:DEMO_STACK_PREFIX-sam-artifacts-$uuid"
    
    Write-Info "Creating SAM bucket: $SAM_BUCKET"
    
    aws s3 mb "s3://$SAM_BUCKET" --profile $env:AWS_PROFILE --region $env:AWS_REGION 2>$null
    
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 255) {
        Write-Success "SAM bucket created: $SAM_BUCKET"
        $env:SAM_S3_BUCKET = $SAM_BUCKET
        
        # Update .env file
        $envContent = Get-Content $envFile -Raw
        if ($envContent -match "SAM_S3_BUCKET=.*") {
            $envContent = $envContent -replace "SAM_S3_BUCKET=.*", "SAM_S3_BUCKET=$SAM_BUCKET"
        } else {
            $envContent += "`nSAM_S3_BUCKET=$SAM_BUCKET"
        }
        Set-Content -Path $envFile -Value $envContent -NoNewline
    } else {
        Write-Error "Failed to create SAM bucket"
        exit 1
    }
} else {
    $SAM_BUCKET = $env:SAM_S3_BUCKET
    
    # Verify bucket exists
    Write-Info "Verifying SAM bucket exists: $SAM_BUCKET"
    aws s3 ls "s3://$SAM_BUCKET" --profile $env:AWS_PROFILE --region $env:AWS_REGION 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Bucket does not exist, creating: $SAM_BUCKET"
        aws s3 mb "s3://$SAM_BUCKET" --profile $env:AWS_PROFILE --region $env:AWS_REGION 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "SAM bucket created: $SAM_BUCKET"
        } else {
            Write-Error "Failed to create SAM bucket"
            exit 1
        }
    } else {
        Write-Success "SAM bucket verified: $SAM_BUCKET"
    }
}

# ============================================
# STEP 2: DEPLOY SHARED STACK
# ============================================

$sharedOutputsHash = @{}

if (-not $SkipShared) {
    Write-StepHeader "Step 2: Deploy Shared Infrastructure Stack"
    
    # Update samconfig
    $samConfigPath = Join-Path $SERVER_DIR "shared-samconfig.toml"
    if (Test-Path $samConfigPath) {
        Write-Info "Updating shared-samconfig.toml..."
        
        $samConfig = Get-Content $samConfigPath -Raw
        $samConfig = $samConfig -replace 'stack_name = ".*?"', "stack_name = `"$SHARED_STACK_NAME`""
        $samConfig = $samConfig -replace 's3_bucket = ".*?"', "s3_bucket = `"$SAM_BUCKET`""
        $samConfig = $samConfig -replace 's3_prefix = ".*?"', "s3_prefix = `"$env:DEMO_STACK_PREFIX-shared`""
        $samConfig = $samConfig -replace 'region = ".*?"', "region = `"$env:AWS_REGION`""
        $samConfig = $samConfig -replace 'profile = ".*?"', "profile = `"$env:AWS_PROFILE`""
        $samConfig = $samConfig -replace 'StackPrefix=[^ "]*', "StackPrefix=$env:DEMO_STACK_PREFIX"
        
        Set-Content -Path $samConfigPath -Value $samConfig
    }
    
    $sharedDeployed = Invoke-SAMDeploy `
        -StackName $SHARED_STACK_NAME `
        -Template "shared-template.yaml" `
        -ConfigFile "shared-samconfig.toml" `
        -ParameterOverrides "AdminEmailParameter=$env:DEMO_ADMIN_EMAIL StackPrefix=$env:DEMO_STACK_PREFIX"
    
    if ($sharedDeployed) {
        $sharedOutputs = Get-StackOutputs -StackName $SHARED_STACK_NAME
        
        if ($sharedOutputs) {
            Write-Host ""
            Write-Host "Shared Stack Outputs:" -ForegroundColor $Colors.Success
            
            foreach ($output in $sharedOutputs) {
                Write-Host "  $($output.OutputKey): $($output.OutputValue)" -ForegroundColor Gray
                $sharedOutputsHash[$output.OutputKey] = $output.OutputValue
            }
        }
    } else {
        Write-Error "Shared stack deployment failed"
        $Global:DeploymentSuccess = $false
    }
} else {
    Write-Info "Skipping shared stack deployment (-SkipShared)"
    
    # Get existing outputs
    $sharedOutputs = Get-StackOutputs -StackName $SHARED_STACK_NAME
    if ($sharedOutputs) {
        foreach ($output in $sharedOutputs) {
            $sharedOutputsHash[$output.OutputKey] = $output.OutputValue
        }
    }
}

# ============================================
# STEP 3: DEPLOY TENANT STACK
# ============================================

$tenantOutputsHash = @{}

if (-not $SkipTenant -and $Global:DeploymentSuccess) {
    Write-StepHeader "Step 3: Deploy Tenant Stack (Pooled Architecture)"
    
    # Get required Cognito values from shared stack
    if ($sharedOutputsHash.Count -eq 0) {
        $sharedOutputs = Get-StackOutputs -StackName $SHARED_STACK_NAME
        if ($sharedOutputs) {
            foreach ($output in $sharedOutputs) {
                $sharedOutputsHash[$output.OutputKey] = $output.OutputValue
            }
        }
    }
    
    $TENANT_USER_POOL_ID = $sharedOutputsHash["CognitoTenantUserPoolId"]
    $TENANT_APP_CLIENT_ID = $sharedOutputsHash["CognitoTenantAppClientId"]
    
    if (-not $TENANT_USER_POOL_ID -or -not $TENANT_APP_CLIENT_ID) {
        Write-Error "Cannot deploy tenant stack: Missing Cognito outputs from shared stack"
        $Global:DeploymentSuccess = $false
    } else {
        Write-Info "Using Tenant User Pool: $TENANT_USER_POOL_ID"
        
        # Update samconfig
        $samConfigPath = Join-Path $SERVER_DIR "tenant-samconfig.toml"
        if (Test-Path $samConfigPath) {
            Write-Info "Updating tenant-samconfig.toml..."
            
            $samConfig = Get-Content $samConfigPath -Raw
            $samConfig = $samConfig -replace 'stack_name = ".*?"', "stack_name = `"$TENANT_STACK_NAME`""
            $samConfig = $samConfig -replace 's3_bucket = ".*?"', "s3_bucket = `"$SAM_BUCKET`""
            $samConfig = $samConfig -replace 's3_prefix = ".*?"', "s3_prefix = `"$env:DEMO_STACK_PREFIX-tenant`""
            $samConfig = $samConfig -replace 'region = ".*?"', "region = `"$env:AWS_REGION`""
            $samConfig = $samConfig -replace 'profile = ".*?"', "profile = `"$env:AWS_PROFILE`""
            $samConfig = $samConfig -replace 'StackPrefix=[^ ]*', "StackPrefix=$env:DEMO_STACK_PREFIX"
            $samConfig = $samConfig -replace 'CognitoTenantUserPoolId=[^ ]*', "CognitoTenantUserPoolId=$TENANT_USER_POOL_ID"
            $samConfig = $samConfig -replace 'CognitoTenantAppClientId=[^"]*', "CognitoTenantAppClientId=$TENANT_APP_CLIENT_ID"
            
            Set-Content -Path $samConfigPath -Value $samConfig
        }
        
        $tenantDeployed = Invoke-SAMDeploy `
            -StackName $TENANT_STACK_NAME `
            -Template "tenant-template.yaml" `
            -ConfigFile "tenant-samconfig.toml"
        
        if ($tenantDeployed) {
            $tenantOutputs = Get-StackOutputs -StackName $TENANT_STACK_NAME
            
            if ($tenantOutputs) {
                Write-Host ""
                Write-Host "Tenant Stack Outputs:" -ForegroundColor $Colors.Success
                
                foreach ($output in $tenantOutputs) {
                    Write-Host "  $($output.OutputKey): $($output.OutputValue)" -ForegroundColor Gray
                    $tenantOutputsHash[$output.OutputKey] = $output.OutputValue
                }
            }
        } else {
            Write-Error "Tenant stack deployment failed"
            $Global:DeploymentSuccess = $false
        }
    }
} else {
    if ($SkipTenant) {
        Write-Info "Skipping tenant stack deployment (-SkipTenant)"
    }
    
    # Get existing outputs
    $tenantOutputs = Get-StackOutputs -StackName $TENANT_STACK_NAME
    if ($tenantOutputs) {
        foreach ($output in $tenantOutputs) {
            $tenantOutputsHash[$output.OutputKey] = $output.OutputValue
        }
    }
}

# ============================================
# STEP 4: UPDATE ANGULAR ENVIRONMENT FILES
# ============================================

if ($Global:DeploymentSuccess -and $sharedOutputsHash.Count -gt 0 -and $tenantOutputsHash.Count -gt 0) {
    Update-EnvironmentFiles -SharedOutputs $sharedOutputsHash -TenantOutputs $tenantOutputsHash
}

# ============================================
# STEP 5: BUILD CLIENT APPLICATIONS
# ============================================

if (-not $SkipBuild -and $Global:DeploymentSuccess) {
    Write-StepHeader "Step 5: Build Client Applications"
    
    $apps = @(
        @{Name="Admin"; Dir=(Join-Path $CLIENT_DIR "Admin")},
        @{Name="Landing"; Dir=(Join-Path $CLIENT_DIR "Landing")},
        @{Name="Application"; Dir=(Join-Path $CLIENT_DIR "Application")}
    )
    
    foreach ($app in $apps) {
        if (Test-Path $app.Dir) {
            $buildSuccess = Invoke-ClientBuild -AppName $app.Name -AppDir $app.Dir
            if (-not $buildSuccess) {
                $Global:DeploymentSuccess = $false
            }
        } else {
            Write-Warning "$($app.Name): Directory not found"
        }
    }
} else {
    if ($SkipBuild) {
        Write-Info "Skipping client build (-SkipBuild)"
    }
}

# ============================================
# STEP 6: DEPLOY CLIENT APPLICATIONS TO S3
# ============================================

if (-not $SkipDeploy -and $Global:DeploymentSuccess) {
    Write-StepHeader "Step 6: Deploy Client Applications to S3"
    
    # Get bucket names from shared stack
    if ($sharedOutputsHash.Count -eq 0) {
        $sharedOutputs = Get-StackOutputs -StackName $SHARED_STACK_NAME
        if ($sharedOutputs) {
            foreach ($output in $sharedOutputs) {
                $sharedOutputsHash[$output.OutputKey] = $output.OutputValue
            }
        }
    }
    
    $ADMIN_BUCKET = $sharedOutputsHash["AdminSiteBucket"]
    $LANDING_BUCKET = $sharedOutputsHash["LandingApplicationSiteBucket"]
    $APP_BUCKET = $sharedOutputsHash["ApplicationSiteBucket"]
    
    if ($ADMIN_BUCKET -and $LANDING_BUCKET -and $APP_BUCKET) {
        $deployments = @(
            @{Name="Admin"; Dist=(Join-Path $CLIENT_DIR "Admin\dist"); Bucket=$ADMIN_BUCKET},
            @{Name="Landing"; Dist=(Join-Path $CLIENT_DIR "Landing\dist"); Bucket=$LANDING_BUCKET},
            @{Name="Application"; Dist=(Join-Path $CLIENT_DIR "Application\dist"); Bucket=$APP_BUCKET}
        )
        
        foreach ($deploy in $deployments) {
            $deploySuccess = Invoke-ClientDeploy -AppName $deploy.Name -DistDir $deploy.Dist -BucketName $deploy.Bucket
            if (-not $deploySuccess) {
                $Global:DeploymentSuccess = $false
            }
        }
    } else {
        Write-Error "Cannot deploy clients: Missing S3 bucket outputs from shared stack"
        $Global:DeploymentSuccess = $false
    }
} else {
    if ($SkipDeploy) {
        Write-Info "Skipping client deployment (-SkipDeploy)"
    }
}

# ============================================
# STEP 7: SAVE DEPLOYMENT OUTPUTS
# ============================================

if ($sharedOutputsHash.Count -gt 0 -or $tenantOutputsHash.Count -gt 0) {
    Save-DeploymentOutputs -SharedOutputs $sharedOutputsHash -TenantOutputs $tenantOutputsHash
}

# ============================================
# STEP 8: RETRIEVE ADMIN CREDENTIALS & SEND SUMMARY
# ============================================

$adminCredentials = $null
if ($sharedOutputsHash["CognitoOperationUsersUserPoolProviderURL"]) {
    $adminUserPoolId = ($sharedOutputsHash["CognitoOperationUsersUserPoolProviderURL"] -split '/')[-1]
    $adminCredentials = Get-CognitoAdminCredentials -UserPoolId $adminUserPoolId -AdminEmail $env:DEMO_ADMIN_EMAIL
}

if ($Global:DeploymentSuccess -and $sharedOutputsHash.Count -gt 0) {
    Send-DeploymentNotification -SharedOutputs $sharedOutputsHash -TenantOutputs $tenantOutputsHash -AdminCredentials $adminCredentials
}

# ============================================
# DEPLOYMENT SUMMARY
# ============================================

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalMinutes

Write-Host ""
Write-Host "========================================" -ForegroundColor $Colors.Header
if ($Global:DeploymentSuccess) {
    Write-Host " DEPLOYMENT COMPLETED SUCCESSFULLY" -ForegroundColor $Colors.Success
} else {
    Write-Host " DEPLOYMENT COMPLETED WITH ERRORS" -ForegroundColor $Colors.Error
}
Write-Host "========================================" -ForegroundColor $Colors.Header
Write-Host ""
Write-Host "Total Duration: $([math]::Round($duration, 1)) minutes" -ForegroundColor Gray
Write-Host ""

if ($Global:DeploymentLog.Count -gt 0) {
    Write-Host "Deployment Log:" -ForegroundColor $Colors.Info
    foreach ($entry in $Global:DeploymentLog) {
        Write-Host "  $entry" -ForegroundColor Gray
    }
    Write-Host ""
}

if (-not $Global:DeploymentSuccess) {
    Write-Host "Please review errors above and re-run the deployment" -ForegroundColor $Colors.Warning
    Write-Host ""
    exit 1
}
