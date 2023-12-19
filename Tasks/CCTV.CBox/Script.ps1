$Object = Invoke-WebRequest -Uri 'https://download.cntv.cn/cbox/update_config.txt' | Read-ResponseContent | ConvertFrom-Json

# Installer
$InstallerUrl = $Object.result.update_url
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '_v([\d\.]+)_').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.status.now | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
