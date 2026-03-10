# Test suite for New-QueryString function
. "$PSScriptRoot\Common.ps1"

function Assert-Equal($Actual, $Expected, $Message) {
  if ($Actual -eq $Expected) {
    Write-Host "[PASS] $Message" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    Write-Host "  Expected: '$Expected'"
    Write-Host "  Actual:   '$Actual'"
    $script:TestsFailed = $true
  }
}

$script:TestsFailed = $false

Write-Host "Running tests for New-QueryString..." -ForegroundColor Cyan

# Test Case 1: Empty hashtable
Assert-Equal (New-QueryString -Parameters @{}) "" "Empty hashtable returns empty string"

# Test Case 2: Single parameter
Assert-Equal (New-QueryString -Parameters @{ id = "123" }) "id=123" "Single parameter"

# Test Case 3: Multiple parameters (sorting check)
Assert-Equal (New-QueryString -Parameters @{ b = "2"; a = "1"; c = "3" }) "a=1&b=2&c=3" "Multiple parameters should be sorted"

# Test Case 4: Special characters encoding
Assert-Equal (New-QueryString -Parameters @{ q = "hello world"; spec = "&=" }) "q=hello+world&spec=%26%3D" "Special characters should be URL encoded"

# Test Case 5: Numeric values
Assert-Equal (New-QueryString -Parameters @{ count = 10; price = 1.5 }) "count=10&price=1.5" "Numeric values should be converted to string and encoded"

# Test Case 6: Null value
Assert-Equal (New-QueryString -Parameters @{ key = $null }) "key=" "Null value should result in empty string value"

if ($script:TestsFailed) {
  Write-Host "`nSome tests failed!" -ForegroundColor Red
  exit 1
} else {
  Write-Host "`nAll tests passed!" -ForegroundColor Green
  exit 0
}
