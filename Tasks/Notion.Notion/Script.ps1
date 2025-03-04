$Prefix = 'https://desktop-release.notion-static.com/'

# x64
$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml
# arm64
$Object2 = Invoke-RestMethod -Uri "${Prefix}arm64-windows.yml" | ConvertFrom-Yaml

if ($Object1.version -ne $Object2.version) {
  $this.Log("x64 version: $($Object1.version)")
  $this.Log("arm64 version: $($Object2.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Prefix $Object2.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
