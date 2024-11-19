$Object1 = Invoke-WebRequest -Uri 'https://download.cntv.cn/cbox/update_config.txt' -MaximumRetryCount 0 | Read-ResponseContent | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.result.update_url | ConvertTo-Https
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '_v([\d\.]+)_').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.status.now | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'
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
