$Object1 = Invoke-RestMethod -Uri 'https://openapi.insta360.com/app/v1/common/upgrade/link_controller_win'

# Version
$this.CurrentState.Version = '{1}.{2}' -f [regex]::Match($Object1.data.appVersion.version, '(\d+(?:\.\d+)+)_build(\d+)').Groups.Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.appVersion.download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.appVersion.update_time | ConvertFrom-UnixTimeMilliseconds

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.appVersion.descriptions.en_us.note | Format-Text
      }

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.appVersion.descriptions.zh_cn.note | Format-Text
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
