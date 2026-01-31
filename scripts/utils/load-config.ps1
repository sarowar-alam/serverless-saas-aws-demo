# Load configuration from .env file
$ErrorActionPreference = "Stop"

$envFile = "$PSScriptRoot\..\..\\.env"

if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: .env file not found at $envFile" -ForegroundColor Red
    Write-Host "Please create .env file from .env.example template" -ForegroundColor Yellow
    exit 1
}

Write-Host "Loading configuration from .env..." -ForegroundColor Cyan

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    
    # Skip empty lines and comments
    if ($line -eq "" -or $line.StartsWith("#")) {
        return
    }
    
    # Parse KEY=VALUE
    if ($line -match "^([^=]+)=(.*)$") {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        
        # Remove quotes if present
        $value = $value -replace '^["'']|["'']$', ''
        
        # Set environment variable
        Set-Item -Path "env:$key" -Value $value
        Write-Host "  $key = $value" -ForegroundColor Gray
    }
}

# Validate required variables
$requiredVars = @(
    "AWS_PROFILE",
    "AWS_REGION",
    "DEMO_STACK_PREFIX",
    "DEMO_ADMIN_EMAIL"
)

$missing = @()
foreach ($var in $requiredVars) {
    if (-not (Test-Path "env:$var") -or [string]::IsNullOrEmpty((Get-Item "env:$var").Value)) {
        $missing += $var
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: Missing required environment variables:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Configuration loaded successfully!" -ForegroundColor Green
Write-Host ""
