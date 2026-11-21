$Object1 = Invoke-RestMethod -Uri 'https://odm.polyv.net/pkg/app/version/all_app_latest_version/'

# Version
$this.CurrentState.Version = $Object1.data.lightGuideClient.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://soft.polyv.net/soft/electron/PolyvDirector/PolyvDirector.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.lightGuideClient.updateTime | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.lightGuideClient.updateContent | Format-Text
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
