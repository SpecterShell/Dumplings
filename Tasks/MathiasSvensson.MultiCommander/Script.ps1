$Object1 = Invoke-RestMethod -Uri 'https://multicommander.com/updates/version.xml'

# Version
$this.CurrentState.Version = $Object1.updates.multicommander.stable.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.updates.multicommander.stable.full.Where({ $_.platform -eq '32bit' }, 'First')[0].url | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.updates.multicommander.stable.full.Where({ $_.platform -eq '64bit' }, 'First')[0].url | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri "https://multicommander.com/ReleaseInfo/$($this.CurrentState.Version.Split('.')[-1])" | ConvertFrom-Html

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://multicommander.com/ReleaseInfo/$($this.CurrentState.Version.Split('.')[-1])"
      }

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.SelectSingleNode('//*[@class="release-date"]').InnerText | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('//*[contains(@class, "release-info")]/div[1]') | Get-TextContent | Format-Text
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
