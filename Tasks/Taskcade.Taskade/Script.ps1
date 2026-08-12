$Prefix = 'https://apps.taskade.com/updates/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.files.Where({ $_.url.EndsWith('.exe') -and $_.url.Contains('_x64') }, 'First')[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Prefix $Object1.files.Where({ $_.url.EndsWith('.exe') -and $_.url.Contains('_arm64') }, 'First')[0].url
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
