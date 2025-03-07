# x86
$Object1 = Invoke-RestMethod -Uri 'https://update.equinox.io/check' -Method Post -Body (
  @{
    app_id  = 'app_c3U4eZcDbjV'
    channel = 'stable'
    os      = 'windows'
    arch    = '386'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json; charset=utf-8'

# x64
$Object2 = Invoke-RestMethod -Uri 'https://update.equinox.io/check' -Method Post -Body (
  @{
    app_id  = 'app_c3U4eZcDbjV'
    channel = 'stable'
    os      = 'windows'
    arch    = 'amd64'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json; charset=utf-8'

# arm64
$Object3 = Invoke-RestMethod -Uri 'https://update.equinox.io/check' -Method Post -Body (
  @{
    app_id  = 'app_c3U4eZcDbjV'
    channel = 'stable'
    os      = 'windows'
    arch    = 'arm64'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json; charset=utf-8'

if (@(@($Object1, $Object2, $Object3) | Sort-Object -Property { $_.release.version } -Unique).Count -gt 1) {
  $this.Log("x86 version: $($Object1.response.app.updatecheck.manifest.version)")
  $this.Log("x64 version: $($Object2.response.app.updatecheck.manifest.version)")
  $this.Log("arm64 version: $($Object3.response.app.updatecheck.manifest.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.release.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.download_url
}

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.download_url
}

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object3.download_url
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
