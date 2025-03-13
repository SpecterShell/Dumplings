$Object1 = Invoke-RestMethod -Uri 'https://www.yuanfudao.com/tutor-app-version/win/app-versions/current' -Body @{
  _productId = '328'
  version    = $this.Status.Contains('New') ? $this.LastState.Version : '6.83.0'
}

# Version
$this.CurrentState.Version = $Object1.currentVersion.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.currentVersion.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.currentVersion.url64
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.alert.alertText | Format-Text
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
