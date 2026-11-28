# The electron-updater feed is the only official source that names the version and the matching
# asset together. The marketing redirect https://capy.ai/download/windows always serves the newest
# build, so the manifest keeps the versioned asset URL the feed resolves to.
$Prefix = 'https://downloads.capy.ai/stable/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-ElectronBuilderUpdateFeed

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = Join-Uri $Prefix $Object1.Files[0].Url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ReleaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotes (en-US)
      $ReleaseNotesPage = "https://capy.ai/changelog/$($this.CurrentState.Version)"
      $ReleaseNotesDocument = Invoke-WebRequest -Uri $ReleaseNotesPage | ConvertFrom-Html
      $ReleaseNotesNode = $ReleaseNotesDocument.SelectSingleNode('(//article/div)[last()]')
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesNode.FirstChild; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }

      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesPage
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
