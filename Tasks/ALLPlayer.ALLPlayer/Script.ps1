# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://allplayer.com/Download/ALLPlayer.exe'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Auto'
    ReadVersion = { param($Path) Read-ProductVersionFromExe -Path $Path }
  })

if ($Result.NeedsMetadata) {
  try {
    $Object1 = Invoke-WebRequest -Uri 'https://www.allplayer.com/changelog' | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//div[contains(./h2, '$($this.CurrentState.Version)')]")
    if ($ReleaseNotesTitleNode) {
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node; $Node = $Node.NextSibling) {
        if ($Node.SelectSingleNode('.//time')) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = $Node.SelectSingleNode('.//time').Attributes['datetime'].Value | Get-Date -AsUTC
        } else {
          $Node
        }
      }
      # ReleaseNotes (en-US)
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
