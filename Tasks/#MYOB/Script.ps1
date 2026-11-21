$Global:DumplingsStorage.MYOBApps = Invoke-RestMethod -Uri 'https://www.myob.com/api/product-downloads' -Method Post -Headers @{ Referer = 'https://www.myob.com/au/support/downloads' } -Body (
  @{
    'locale'  = 'en-AU'
    'preview' = $false
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'
