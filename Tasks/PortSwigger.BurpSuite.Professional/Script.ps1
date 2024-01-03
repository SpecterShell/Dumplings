$Object1 = Invoke-RestMethod -Uri 'https://portswigger.net/Burp/Releases/CheckForUpdates?product=community&channel=Stable&version=0'

# Version
$this.CurrentState.Version = $Object1.updates[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://portswigger-cdn.net/burp/releases/download?product=pro&version=$($this.CurrentState.Version)&type=WindowsX64"
}

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.updates[0].description | Format-Text
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = $Object1.updates[0].releaseNotesUrl
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Object2.SelectSingleNode('//*[@id="PostAdditionalInfo"]').InnerText.Trim(),
        "dd MMMM yyyy 'at' HH:mm 'UTC'",
          (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
