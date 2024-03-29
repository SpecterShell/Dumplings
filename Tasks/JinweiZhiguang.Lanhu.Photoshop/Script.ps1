$Object1 = Invoke-RestMethod -Uri 'https://lanhuapp.com/api/project/app_version?apptype=lanhu_ps_windows'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.result.url
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.result.create_time | Get-Date -AsUTC

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
