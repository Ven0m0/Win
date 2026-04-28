$files = @()
"files=$($files -join ',')" | Out-File -FilePath output.txt -Encoding utf8BOM
