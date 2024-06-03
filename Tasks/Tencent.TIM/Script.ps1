$Object1 = Invoke-RestMethod -Uri 'https://im.qq.com/rainbow/TIMDownload/' | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.app.download.pcLink.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.app.download.pcDatetime | Get-Date -Format 'yyyy-MM-dd'
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
