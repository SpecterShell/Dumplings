$Object1 = Invoke-RestMethod -Uri 'https://groovy.jfrog.io/ui/api/v1/ui/v2/treebrowser' -Method Post -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } -ContentType 'application/json' -Body @(
  @{
    type        = 'paginatedJunction'
    repoType    = 'local'
    repoKey     = 'dist-release-local'
    path        = 'groovy-windows-installer'
    repoPkgType = 'Generic'
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object1.data.text -match '^groovy-3\.[\d\.]+$' -replace '^groovy-([\d\.]+)$', '$1' |
  Sort-Object -Property { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } -Bottom 1

$Object2 = Invoke-RestMethod -Uri 'https://groovy.jfrog.io/ui/api/v1/ui/v2/treebrowser' -Method Post -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } -ContentType 'application/json' -Body @(
  @{
    type        = 'paginatedJunction'
    repoType    = 'local'
    repoKey     = 'dist-release-local'
    path        = "groovy-windows-installer/groovy-$($this.CurrentState.Version)"
    repoPkgType = 'Generic'
  } | ConvertTo-Json -Compress
)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://groovy.jfrog.io/artifactory/dist-release-local/$($Object2.data.Where({ $_.text.EndsWith('.msi') }, 'First')[0].path)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
