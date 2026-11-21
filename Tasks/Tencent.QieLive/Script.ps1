$Object1 = Invoke-RestMethod -Uri 'https://live.qq.com/api/client_app/get_download_address?platform=1'

# Version
$this.CurrentState.Version = $Object1.data.pc_obs.version_name

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.pc_obs.down_url | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.pc_obs.dateline | ConvertFrom-UnixTimeSeconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.pc_obs.update_content | Format-Text
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
