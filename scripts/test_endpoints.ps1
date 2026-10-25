param (
    [string]$BaseUrl = "http://localhost:8000"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Testing Containerized RESTful API on $BaseUrl" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$TotalTests = 0
$PassedTests = 0

function Run-Test {
    param (
        [string]$Name,
        [scriptblock]$Action
    )
    $script:TotalTests++
    Write-Host "`n[TEST $script:TotalTests] $Name..." -NoNewline
    try {
        & $Action
        Write-Host " [PASS]" -ForegroundColor Green
        $script:PassedTests++
    }
    catch {
        Write-Host " [FAIL]" -ForegroundColor Red
        Write-Host "   Error: $_" -ForegroundColor DarkRed
    }
}

# 1. Test Health Check
Run-Test "GET /health (HTTP 200 & {'status': 'healthy'})" {
    $response = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -TimeoutSec 10
    if ($response.status -ne "healthy") {
        throw "Expected status 'healthy' but got '$($response.status)'"
    }
}

# 2. Test Create Item
$CreatedItemId = $null
$ItemName = "Automated Test Item - $(Get-Random)"
$ItemDesc = "Verified via automated test script on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Run-Test "POST /items (HTTP 201 & Valid Item Object)" {
    $body = @{
        name        = $ItemName
        description = $ItemDesc
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$BaseUrl/items" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
    
    if (-not $response.id) {
        throw "Response missing 'id' field"
    }
    if ($response.name -ne $ItemName) {
        throw "Expected name '$ItemName' but got '$($response.name)'"
    }
    if ($response.description -ne $ItemDesc) {
        throw "Expected description '$ItemDesc' but got '$($response.description)'"
    }
    if (-not $response.created_at) {
        throw "Response missing 'created_at' field"
    }
    $script:CreatedItemId = $response.id
}

# 3. Test List Items
Run-Test "GET /items (HTTP 200 & Array containing created item)" {
    $items = Invoke-RestMethod -Uri "$BaseUrl/items" -Method Get -TimeoutSec 10
    
    if ($items -isnot [System.Array]) {
        throw "Expected array response but received: $($items.GetType().FullName)"
    }
    
    $found = $items | Where-Object { $_.id -eq $script:CreatedItemId }
    if (-not $found) {
        throw "Created item with ID '$script:CreatedItemId' was not found in GET /items list"
    }
}

# 4. Test Validation Error
Run-Test "POST /items validation (HTTP 422 on missing required field)" {
    $invalidBody = @{
        description = "This should fail because name is missing"
    } | ConvertTo-Json

    $failedAsExpected = $false
    try {
        Invoke-RestMethod -Uri "$BaseUrl/items" -Method Post -Body $invalidBody -ContentType "application/json" -TimeoutSec 10
    }
    catch {
        $failedAsExpected = $true
    }

    if (-not $failedAsExpected) {
        throw "Expected request to fail with validation error, but it succeeded."
    }
}

$SummaryColor = if ($PassedTests -eq $TotalTests) { "Green" } else { "Red" }
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Test Summary: $PassedTests / $TotalTests tests passed." -ForegroundColor $SummaryColor
Write-Host "==========================================================" -ForegroundColor Cyan

if ($PassedTests -ne $TotalTests) {
    exit 1
}
