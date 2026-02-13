# Isolated test for RefreshSchedule update debugging
# Run this to test only the RefreshSchedule update functionality

# Load test declarations
. (Join-Path $PSScriptRoot "declarations.ps1")

# Load all functions
$CodePath = Join-Path (Split-Path $PSScriptRoot) "Code"
Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

# Connect to test environment
Write-Host "`n=== Connecting to Admin Service ===" -ForegroundColor Cyan
$params = @{ SiteServer = $script:TestSiteServer }
if($script:TestSkipCertificateCheck){ $params.SkipCertificateCheck = $true }
if($null -ne $script:TestCredential){ $params.Credential = $script:TestCredential }
Connect-CMAS @params

# Get test data
$testData = $script:TestData['Set-CMASCollection'].UpdateRefreshSchedule

Write-Host "`n=== Test Data ===" -ForegroundColor Cyan
Write-Host "CollectionName: $($testData.CollectionName)" -ForegroundColor Yellow
Write-Host "RefreshType: $($testData.RefreshType)" -ForegroundColor Yellow
Write-Host "RefreshSchedule:" -ForegroundColor Yellow
$testData.RefreshSchedule | Format-Table -AutoSize

# Check if collection exists, if not create it
Write-Host "`n=== Checking for existing collection ===" -ForegroundColor Cyan
$existingCollection = Get-CMASCollection -Name $testData.CollectionName -ErrorAction SilentlyContinue

if (-not $existingCollection) {
    Write-Host "Collection not found, creating it..." -ForegroundColor Yellow
    New-CMASCollection -Name $testData.CollectionName -LimitingCollectionId "SMS00001" -RefreshType $testData.RefreshType -ErrorAction Stop
    Start-Sleep -Seconds 2
    $existingCollection = Get-CMASCollection -Name $testData.CollectionName
}

Write-Host "`nCurrent collection state:" -ForegroundColor Cyan
Write-Host "  Name: $($existingCollection.Name)" -ForegroundColor White
Write-Host "  CollectionID: $($existingCollection.CollectionID)" -ForegroundColor White
Write-Host "  RefreshType: $($existingCollection.RefreshType)" -ForegroundColor White
Write-Host "  LimitToCollectionID: $($existingCollection.LimitToCollectionID)" -ForegroundColor White
Write-Host "  RefreshSchedule: $($existingCollection.RefreshSchedule)" -ForegroundColor White

if ($existingCollection.RefreshSchedule) {
    Write-Host "`nExisting RefreshSchedule details:" -ForegroundColor Cyan
    $existingCollection.RefreshSchedule | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Gray
}

# Test the update with verbose output
Write-Host "`n=== Attempting RefreshSchedule Update ===" -ForegroundColor Cyan
Write-Host "Setting RefreshSchedule to:" -ForegroundColor Yellow
$testData.RefreshSchedule | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Gray

try {
    Set-CMASCollection -CollectionName $testData.CollectionName -RefreshSchedule $testData.RefreshSchedule -Verbose
    Write-Host "`nSUCCESS: RefreshSchedule updated!" -ForegroundColor Green

    Start-Sleep -Seconds 2
    $updatedCollection = Get-CMASCollection -Name $testData.CollectionName
    Write-Host "`nUpdated collection state:" -ForegroundColor Cyan
    Write-Host "  RefreshType: $($updatedCollection.RefreshType)" -ForegroundColor White
    Write-Host "  RefreshSchedule:" -ForegroundColor White
    $updatedCollection.RefreshSchedule | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Gray

} catch {
    Write-Host "`nFAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nFull Error:" -ForegroundColor Red
    $_ | Format-List * -Force

    if ($_.Exception.InnerException) {
        Write-Host "`nInner Exception:" -ForegroundColor Red
        $_.Exception.InnerException | Format-List * -Force
    }
}
