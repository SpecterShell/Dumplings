$Global:DumplingsStorage.MYOBApps = Invoke-RestMethod -Uri 'https://www.myob.com/api/product-downloads' -Method Post -Body (
  @{
    'locale'  = 'en-AU'
    'preview' = $false
  } | ConvertTo-Json -Compress
) -ContentType 'text/plain;charset=UTF-8'
