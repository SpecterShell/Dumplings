# x86
$Object1 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2/json' -Method Post -Headers @{ Range = 'bytes=5-' } -Body (
  @{
    request = @{
      # acceptformat = 'crx3,puff'
      app      = @(@{ ap = 'x86'; appid = '{8A69D345-D564-463c-AFF1-A69D9E530F96}'; updatecheck = @{} })
      os       = @{ arch = 'x86'; platform = 'Windows'; version = '10.0.22000' }
      protocol = '3.1'
    }
  } | ConvertTo-Json -Depth 5 -Compress
)

# x64
$Object2 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2/json' -Method Post -Headers @{ Range = 'bytes=5-' } -Body (
  @{
    request = @{
      # acceptformat = 'crx3,puff'
      app      = @(@{ ap = 'x64'; appid = '{8A69D345-D564-463c-AFF1-A69D9E530F96}'; updatecheck = @{} })
      os       = @{ arch = 'x86_64'; platform = 'Windows'; version = '10.0.22000' }
      protocol = '3.1'
    }
  } | ConvertTo-Json -Depth 5 -Compress
)

# arm64
$Object3 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2/json' -Method Post -Headers @{ Range = 'bytes=5-' } -Body (
  @{
    request = @{
      # acceptformat = 'crx3,puff'
      app      = @(@{ ap = 'arm64'; appid = '{8A69D345-D564-463c-AFF1-A69D9E530F96}'; updatecheck = @{} })
      os       = @{ arch = 'arm64'; platform = 'Windows'; version = '10.0.22000' }
      protocol = '3.1'
    }
  } | ConvertTo-Json -Depth 5 -Compress
)

if (@(@($Object1, $Object2, $Object3) | Sort-Object -Property { $_.response.app.updatecheck.manifest.version } -Unique).Count -gt 1) {
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.response.app.updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = ($Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object2.response.app.updatecheck.manifest.packages.package[0].name
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = ($Object2.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object1.response.app.updatecheck.manifest.packages.package[0].name
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = ($Object3.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object3.response.app.updatecheck.manifest.packages.package[0].name
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
