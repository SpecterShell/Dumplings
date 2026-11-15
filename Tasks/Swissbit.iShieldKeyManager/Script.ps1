$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://www.swissbit.com/files/public/ikm2/iShield_Key_Management_Kit_Windows.zip'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'LastModified'
    # The server redirects HEAD requests in a loop, so probe and download with GET
    Method      = 'GET'
    ReadVersion = { param($Path)
      $ZipArchive = [System.IO.Compression.ZipFile]::OpenRead($Path)
      try {
        $VersionEntry = $ZipArchive.Entries.Where({ $_.FullName.EndsWith('version.txt') }, 'First')[0]
        $StreamReader = [System.IO.StreamReader]::new($VersionEntry.Open())
        try {
          $StreamReader.ReadToEnd().Trim() -replace '^v'
        } finally {
          $StreamReader.Dispose()
        }
      } finally {
        $ZipArchive.Dispose()
      }
    }
  })

if ($Result.NeedsMetadata -and $Result.Artifacts[0].Path) {
  try {
    $ZipArchive = [System.IO.Compression.ZipFile]::OpenRead($Result.Artifacts[0].Path)
    try {
      $ChangeLogEntry = $ZipArchive.Entries.Where({ $_.FullName.EndsWith('CHANGELOG.md') }, 'First')[0]
      $StreamReader = [System.IO.StreamReader]::new($ChangeLogEntry.Open())
      try {
        $ChangeLog = $StreamReader.ReadToEnd()
      } finally {
        $StreamReader.Dispose()
      }
    } finally {
      $ZipArchive.Dispose()
    }

    $ReleaseNotesObject = $ChangeLog | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
    $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")
    if ($ReleaseNotesTitleNode) {
      if ($ReleaseNotesTitleNode.InnerText -match '(\d{4}-\d{2}-\d{2})') {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Log("No ReleaseTime for version $($Result.Artifacts[0].Version)", 'Warning')
      }

      # ReleaseNotes (en-US)
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$this.CompleteInstallerUpdates($Result)
