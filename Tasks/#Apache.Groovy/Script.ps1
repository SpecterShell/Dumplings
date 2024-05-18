$Global:DumplingsStorage.ApacheGroovyFolders = Invoke-RestMethod -Uri 'https://groovy.jfrog.io/ui/api/v1/ui/v2/treebrowser' -Method Post -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } -ContentType 'application/json' -Body @(
  @{
    type        = 'paginatedJunction'
    repoType    = 'local'
    repoKey     = 'dist-release-local'
    path        = 'groovy-windows-installer'
    repoPkgType = 'Generic'
  } | ConvertTo-Json -Compress
)
