$Object1 = (Invoke-RestMethod -Uri 'https://www.eizo.co.jp/update/ScreenInStyle.json').update_info.Where({ $_.target.os -eq 'windows' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.package.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.package.urls.en
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ja-JP'
  InstallerUrl    = $Object1.package.urls.'ja-JP'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.package.description.en | Format-Text
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
