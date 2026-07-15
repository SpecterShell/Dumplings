$Prefix = 'https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/manifest/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest-x64-win.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url '../windows-arm/Antigravity-arm64.exe'
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
