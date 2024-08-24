$Object1 = Invoke-RestMethod -Uri 'https://data.codecguide.com/klcp_update.ini' | ConvertFrom-Ini

# Version
$RawVersionLength = $Object1.Complete.version.Length
$this.CurrentState.Version = $Object1.Complete.version.Insert($RawVersionLength - 1, '.').Insert($RawVersionLength - 2, '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://files2.codecguide.com/K-Lite_Codec_Pack_$($Object1.Complete.version)_Full.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.Complete.date, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://codecguide.com/changelogs_full.htm' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//td[@class='tdcontent']/h4[contains(text(), 'to $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h4'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
