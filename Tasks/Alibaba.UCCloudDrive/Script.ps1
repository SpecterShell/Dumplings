$Object1 = Invoke-RestMethod -Uri 'https://drive.uc.cn/api/client_version'

if (-not $Object1.data.winInstallerUrl.Contains('UCCloudDrive')) {
  $this.Log('The installer is not a UCCloudDrive installer', 'Warning')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.winInstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.upgradeAlertModal.Where({ $_.system -eq 'windows' }, 'First')[0].descText | Format-Text
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
