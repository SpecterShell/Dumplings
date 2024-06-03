$Object1 = Invoke-RestMethod -Uri 'https://sas.qq.com/cgi-bin/ke_download_pcClient'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.result.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'EduInstall_([\d\.]+)_.+\.exe').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.result.publish_time | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.result.desc | Format-Text
      }
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
