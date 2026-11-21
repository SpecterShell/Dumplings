$Object1 = Invoke-RestMethod -Uri 'https://joyedit.jd.com/api/v1/saas/desktop/update/v1/policy?channel=stable&platform=win32&arch=x64'

# Version
$this.CurrentState.Version = $Object1.data.latestVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.assets.Where({ $_.packageType -eq 'nsis' }, 'First')[0].fileUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.assets.Where({ $_.packageType -eq 'nsis' }, 'First')[0].createTime.ToUniversalTime()

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.releaseNotes | Format-Text
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
