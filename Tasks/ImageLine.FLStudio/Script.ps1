$Object1 = (Invoke-RestMethod -Uri 'https://support.image-line.com/flstudiorss/product_version_xml.php').ilversioninfo.item.Where({ $_.guid -eq '320' -and $_.os -eq 'windows' })[0]

# Version
$this.CurrentState.Version = $Object1.version
$ShortVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.' -replace '\.0+$'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.download_url.Replace('demodownload.image-line.com', 'install.image-line.com')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.versionDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.image-line.com/fl-studio-learning/fl-studio-online-manual/html/WhatsNew.htm' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//td[@id='rightcol']/h3[contains(text(), '${ShortVersion}')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
