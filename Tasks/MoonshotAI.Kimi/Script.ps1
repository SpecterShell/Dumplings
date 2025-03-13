$Object1 = Invoke-RestMethod -Uri 'https://appsupport.moonshot.cn/api/startup' -Method Post -Headers @{
  'x-msh-platform' = 'windows'
  'x-msh-version'  = $this.Status.Contains('New') ? '1.1.9' : $this.LastState.Version
} -Body '{}' -ContentType 'application/json'

if ($Object1.upgrade.is_latest_version) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.upgrade.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.upgrade.apk_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.upgrade.upgrade_dialog.content | Format-Text
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
