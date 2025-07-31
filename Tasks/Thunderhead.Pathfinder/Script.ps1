$ReleaseNotesUrl = Get-RedirectedUrl -Uri 'https://support.thunderheadeng.com/release-notes/pathfinder/latest'
$Object1 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode("//*[contains(@x-data, 'availableDownloads')]").Attributes['x-data'].Value | ConvertTo-HtmlDecodedText | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://www.thunderheadeng.net/releases/' $Object2.availableDownloads.msi
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:-\d+)+)').Groups[1].Value.Replace('-', '.') -replace '^20'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.SelectSingleNode("//h3[contains(text(), `"What's New`")]/ancestor::*[1]") | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
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
    if ("20$($this.CurrentState.Version.Split('.')[0])" -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
