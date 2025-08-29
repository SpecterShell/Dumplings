$Object1 = Invoke-WebRequest -Uri 'https://meet.sangoma.com/apps/desktop/latest/windows/latest.yml'
$Object2 = $Object1 | Read-ResponseContent | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = [regex]::Match($Object1.BaseResponse.RequestMessage.RequestUri.AbsoluteUri, '(\d+(?:\.\d+)+(?:-\d+)?)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri "https://meet.sangoma.com/apps/desktop/$($this.CurrentState.Version)/windows/" $Object2.files.Where({ $_.url.Contains('ia32') }, 'First')[0].url | Split-Uri -LeftPart Path
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri "https://meet.sangoma.com/apps/desktop/$($this.CurrentState.Version)/windows/" $Object2.files.Where({ $_.url.Contains('x64') }, 'First')[0].url | Split-Uri -LeftPart Path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.releaseDate | Get-Date -AsUTC
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
