$Object1 = Invoke-RestMethod -Uri 'https://clearvpn.com/downloads/windows/com.macpaw.clearvpn.windows.xml'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.enclosure.url
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Auto'
    ReadVersion = { param($Path) Read-ProductVersionFromMsi -Path $Path }
  })

if ($Result.NeedsMetadata) {
  try {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object1.pubDate | Get-Date -AsUTC

    $ReleaseNotesObject = $Object1.description | ConvertFrom-Html
    $ReleaseNotesNode = $ReleaseNotesObject.SelectSingleNode('//div[@lang="en"]')
    if ($ReleaseNotesNode) {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNode | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$this.CompleteInstallerUpdates($Result)
