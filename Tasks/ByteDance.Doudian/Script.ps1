$Object1 = Invoke-RestMethod -Uri "https://api.toutiaoapi.com/service/settings/v3/?aid=430651&device_platform=pc&from_version=$($this.Status.Contains('New') ? '1.1.7' : $this.LastState.Version)"

# Version
$this.CurrentState.Version = $Object1.data.settings.doudian_pc_update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.settings.doudian_pc_update.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.settings.doudian_pc_update.notes
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
