$Object1 = Invoke-RestMethod -Uri 'https://s3.us-west-2.amazonaws.com/io.cribl.cdn/dl/cribl_latest_versions.json'

# Version
$this.CurrentState.Version = $Object1[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[0].release.win_msi.build
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1[0].notes.edge.build
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes("//article/div[@class='markdown']/div[@class='release-table-container']/following-sibling::node()") ?? $Object2.SelectSingleNode("//article/div[@class='markdown']") | Get-TextContent | Format-Text
      }

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('.//*[@class="release-table__date"]').InnerText, '(20\d{2}\W+\d{1,2}\W+\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
