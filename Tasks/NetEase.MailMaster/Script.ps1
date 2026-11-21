$Object1 = Invoke-RestMethod -Uri 'http://fm.dl.126.net/mailmaster/update2/update_config.json'

# Version
$this.CurrentState.Version = $Object1.full[0].ver

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.full[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.full[0].introduction | Split-LineEndings | Select-Object -Skip 1 | Format-Text
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
