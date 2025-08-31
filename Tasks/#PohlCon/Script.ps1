$Global:DumplingsStorage.PohlConApps = Invoke-RestMethod -Uri 'https://pohlcon.com/en-de/api/downloads-filter' -Method Post -Body (
  @{
    'downloadQuery'    = ''
    'namingConvention' = @('digitals')
    'productTypes'     = @()
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'
