$Object1 = (Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=108827').Content | Get-EmbeddedJson -StartsFrom 'window.__DLCDetails__=' | ConvertFrom-Json
$Object2 = $Object1.dlcDetailsView.downloadFile

# x86
$Object3 = $Object2.Where({ $_.name -eq 'dnim-win-x86.exe' }, 'First')[0]
# x64
$Object4 = $Object2.Where({ $_.name -eq 'dnim-win-x64.exe' }, 'First')[0]
# arm64
$Object5 = $Object2.Where({ $_.name -eq 'dnim-win-arm64.exe' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object4.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'portable'
  InstallerUrl  = $Object3.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'portable'
  InstallerUrl  = $Object4.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'portable'
  InstallerUrl  = $Object5.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object4.datePublished | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object2.Where({ $_.name -eq 'RELEASE_NOTES.md' }, 'First')[0].url
      }

      $ReleaseNotesObject = Invoke-RestMethod -Uri $ReleaseNotesUrl | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis'
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode('./h2[1]')
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
        }
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
