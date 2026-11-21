$Object1 = Invoke-RestMethod -Uri 'https://portswigger.net/Burp/Releases/CheckForUpdates?product=desktop&channel=Stable&version=0'

# Version
$this.CurrentState.Version = $Object1.updates[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://portswigger.net/burp/releases/download?product=desktop&version=$($this.CurrentState.Version)&type=WindowsX64"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://portswigger.net/burp/releases/download?product=desktop&version=$($this.CurrentState.Version)&type=WindowsArm64"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.updates[0].description | Format-Text
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1.updates[0].releaseNotesUrl
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Object2.SelectSingleNode('//*[@id="PostAdditionalInfo"]').InnerText.Trim(),
        "dddd, d MMMM yyyy 'at' HH:mm 'UTC'",
        (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'
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
