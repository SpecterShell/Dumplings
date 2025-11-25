# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://valentin-software.com/downloads/geotsol/latest'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

# RealVersion
$this.CurrentState.RealVersion = "GeoTSOL $($this.CurrentState.Version.Split('.')[0])"

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://valentin-software.com/en/products/geotsol/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='title' and contains(text(), 'GeoT*SOL $($this.CurrentState.Version.Split('.')[0]) Release $($this.CurrentState.Version.Split('.')[1])')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '([A-Za-z]+\W+\d{1,2}(?:st|nd|rd|th)\W+20\d{2})').Groups[1].Value,
          [string[]]@(
            "MMMM d'st' yyyy", "MMMM dd'st' yyyy",
            "MMMM d'nd' yyyy", "MMMM dd'nd' yyyy",
            "MMMM d'rd' yyyy", "MMMM dd'rd' yyyy",
            "MMMM d'th' yyyy", "MMMM dd'th' yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@class="answer"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Config.WinGetNewPackageIdentifier = $this.Config.WinGetIdentifier -replace '20\d{2}', $this.CurrentState.Version.Split('.')[0]
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'PackageName'
        Value  = { $_ -replace '20\d{2}', $this.CurrentState.Version.Split('.')[0] }
      }
      $this.CurrentState.Installer[0].ProductCode = "GeoT*SOL $($this.CurrentState.Version.Split('.')[0])_is1"
    }
    $this.Submit()
  }
}
