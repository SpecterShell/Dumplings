$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent -H 'Referer: https://www.google.com/' 'https://www.bloomberg.com/professional/wp-json/bb-api/v1/get_downloads_feed_data?feed_order=release_date&order_direction=DESC&date_format=M%20j,%20Y&category=3&date_options=default' | Join-String -Separator "`n" | ConvertFrom-Json -AsHashtable
$Object2 = $Object1.data.GetEnumerator().Where({ $_.Value.post_title -eq 'Bloomberg Terminal – New/Upgrade Installation' }, 'First')[0].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.upload_file
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.post_date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.bloomberg.com/professional/support/documentation/release-notes/' | Join-String -Separator "`n" | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//tr[contains(./td[1]/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./td[2]').InnerText, '([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{2})').Groups[1].Value,
          [string[]]@(
            "MMMM d'st' yyyy",
            "MMMM d'nd' yyyy",
            "MMMM d'rd' yyyy",
            "MMMM d'th' yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./td[3]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
