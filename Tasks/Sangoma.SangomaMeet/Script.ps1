$Object1 = Invoke-RestMethod -Uri 'https://meet.sangoma.com/apps/desktop/latest/windows/latest.yml' | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri "https://meet.sangoma.com/apps/desktop/$($this.CurrentState.Version)/windows/" $Object1.files.Where({ $_.url.Contains('ia32') }, 'First')[0].url | Split-Uri -LeftPart Path
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri "https://meet.sangoma.com/apps/desktop/$($this.CurrentState.Version)/windows/" $Object1.files.Where({ $_.url.Contains('x64') }, 'First')[0].url | Split-Uri -LeftPart Path
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
