$Object1 = Invoke-WebRequest -Uri 'https://download.cntv.cn/cbox/update_config.txt' | Read-ResponseContent | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.result.update_url
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '_v([\d\.]+)_').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.status.now | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
