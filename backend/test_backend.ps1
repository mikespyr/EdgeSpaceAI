$base = "http://127.0.0.1:8000"

Write-Host "Health:"
Invoke-RestMethod "$base/health" | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host "Testing AI endpoint..."
$body = @{
    question = "Πώς σε λένε;"
    app_context = "EdgeSpace AI test context"
    conversation = @()
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
    -Uri "$base/api/v1/ai/chat" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body | ConvertTo-Json -Depth 5
