# Validate Prerequisites for Demo Deployment
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Validating Prerequisites" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allValid = $true

Write-Host "Checking AWS CLI..." -ForegroundColor Yellow
try {
    $awsVersion = aws --version 2>&1
    Write-Host "  OK AWS CLI found" -ForegroundColor Green
} catch {
    Write-Host "  FAIL AWS CLI not found" -ForegroundColor Red
    $allValid = $false
}

Write-Host "Checking SAM CLI..." -ForegroundColor Yellow
try {
    $samVersion = sam --version 2>&1
    Write-Host "  OK SAM CLI found" -ForegroundColor Green
} catch {
    Write-Host "  FAIL SAM CLI not found" -ForegroundColor Red
    $allValid = $false
}

Write-Host "Checking Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "  OK Python found" -ForegroundColor Green
} catch {
    Write-Host "  FAIL Python not found" -ForegroundColor Red
    $allValid = $false
}

Write-Host "Checking Node.js..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version 2>&1
    Write-Host "  OK Node.js found" -ForegroundColor Green
} catch {
    Write-Host "  FAIL Node.js not found" -ForegroundColor Red
    $allValid = $false
}

Write-Host "Checking Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>&1
    Write-Host "  OK Docker found" -ForegroundColor Green
} catch {
    Write-Host "  FAIL Docker not found" -ForegroundColor Red
    $allValid = $false
}

Write-Host ""
if ($allValid) {
    Write-Host "All prerequisites validated!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some prerequisites are missing" -ForegroundColor Red
    exit 1
}
