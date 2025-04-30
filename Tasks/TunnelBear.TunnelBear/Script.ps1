
$Object1 = Invoke-RestMethod -Uri 'https://tunnelbear.s3.amazonaws.com/downloads/pc/update_windows.xml'

# Version
$this.CurrentState.Version = $Object1.item.version

# Installer
# The installer file in ./supportedOS is older than the one in ./
# Use the latter one here
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.item.url.Replace('/supportedOS', '')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.item.changelog.Replace('/supportedOS', '')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('//*[@id="content"]') | Get-TextContent | Format-Text
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
