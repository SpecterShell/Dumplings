$Object1 = Invoke-RestMethod -Uri 'https://lanhuapp.com/api/project/app_version?apptype=lanhu_axure_windows'

# Version
$this.CurrentState.Version = $Object1.result.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.result.url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.result.create_time | Get-Date -AsUTC
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
