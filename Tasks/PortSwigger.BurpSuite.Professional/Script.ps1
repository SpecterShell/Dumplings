$Object = Invoke-RestMethod -Uri 'https://portswigger.net/Burp/Releases/CheckForUpdates?product=community&channel=Stable&version=0'

# Version
$Task.CurrentState.Version = $Object.updates[0].version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://portswigger-cdn.net/burp/releases/download?product=pro&version=$($Task.CurrentState.Version)&type=WindowsX64"
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.updates[0].description | Format-Text
}

# ReleaseNotesUrl
$ReleaseNotesUrl = $Object.updates[0].releaseNotesUrl
$Task.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      # ReleaseTime
      $Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Object2.SelectSingleNode('//*[@id="PostAdditionalInfo"]').InnerText.Trim(),
        "dd MMMM yyyy 'at' HH:mm 'UTC'",
          (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
