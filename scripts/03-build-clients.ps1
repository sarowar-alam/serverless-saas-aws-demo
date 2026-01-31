# Build All Client Applications (Admin, Landing, Application)
# This script builds all three Angular applications

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Building Client Applications" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
. "$PSScriptRoot\utils\load-config.ps1"

$CLIENT_DIR = "$PSScriptRoot\..\client"
$apps = @("Admin", "Landing", "Application")

$totalStart = Get-Date

foreach ($app in $apps) {
    $appDir = Join-Path $CLIENT_DIR $app
    
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    Write-Host " Building $app UI" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    Write-Host ""
    
    if (-not (Test-Path $appDir)) {
        Write-Host "  Directory not found: $appDir" -ForegroundColor Yellow
        continue
    }
    
    Push-Location $appDir
    
    try {
        # Install dependencies
        Write-Host "Installing dependencies..." -ForegroundColor Cyan
        if ($app -eq "Application") {
            npm install --legacy-peer-deps
        } else {
            npm install
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "npm install failed"
        }
        
        Write-Host "  Dependencies installed" -ForegroundColor Green
        Write-Host ""
        
        # Build application
        Write-Host "Building application (this may take 3-5 minutes)..." -ForegroundColor Cyan
        npm run build
        
        if ($LASTEXITCODE -ne 0) {
            throw "npm build failed"
        }
        
        Write-Host "  Build completed" -ForegroundColor Green
        Write-Host ""
        
    } catch {
        Write-Host "  Build failed: $_" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    
    Pop-Location
}

$totalEnd = Get-Date
$duration = ($totalEnd - $totalStart).TotalMinutes

Write-Host "========================================" -ForegroundColor Green
Write-Host " All clients built successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Total time: $([math]::Round($duration, 1)) minutes" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  Run: .\scripts\geturl.ps1" -ForegroundColor Gray
Write-Host ""
