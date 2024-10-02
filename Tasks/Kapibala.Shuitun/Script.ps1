$Object1 = Invoke-RestMethod -Uri 'https://releases.shuitunapp.com/latest.json'

# Version
$this.CurrentState.Version = $Object1.version -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.platforms.'windows-x86_64'.url -replace '\.zip$', '.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime()

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.notes | Format-Text
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
