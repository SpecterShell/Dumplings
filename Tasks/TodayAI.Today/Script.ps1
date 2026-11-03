# x64
$Prefix1 = 'https://releases.today.ai/apps/today/desktop/windows/release/x64/'
$Object1 = Invoke-RestMethod -Uri "${Prefix1}latest.yml" | ConvertFrom-Yaml

# arm64
$Prefix2 = 'https://releases.today.ai/apps/today/desktop/windows/release/arm64/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml" | ConvertFrom-Yaml

if ($Object1.version -ne $Object2.version) {
  $this.Log("Inconsistent versions: x64: $($Object1.version), arm64: $($Object2.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix1 $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Prefix2 $Object2.files[0].url
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
    $this.Submit()
  }
}
