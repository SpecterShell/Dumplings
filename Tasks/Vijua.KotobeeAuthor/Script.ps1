$Object1 = Invoke-RestMethod -Uri 'https://admin.kotobee.com/releases/author/releases.json'

# Version
$this.CurrentState.Version = $Object1[-1].ver

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://files.kotobee.com/author/releases/kotobeeauthor-$($this.CurrentState.Version)-win32.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://files.kotobee.com/author/releases/kotobeeauthor-$($this.CurrentState.Version)-win64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1[-1].date.Split(',')[-1] -replace '\bSept\b', 'Sep' | Get-Date -AsUTC # Strip off day of week from the date string as it may be incorrect
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri "https://admin.kotobee.com/releases/author/$($this.CurrentState.Version)/release.json"

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object2.releaseNotes
      }

      $Object3 = Invoke-WebRequest -Uri $Object2.updateUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3 | Get-TextContent | Format-Text
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
