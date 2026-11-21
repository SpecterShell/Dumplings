# x86
# $Object1 = Invoke-RestMethod -Uri 'https://update.vivaldi.com/update/1.0/win/appcast.xml'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://update.vivaldi.com/update/1.0/win/appcast.x64.xml'
# arm64
$Object3 = Invoke-RestMethod -Uri 'https://update.vivaldi.com/update/1.0/win/appcast.arm64.xml'

# Version
$this.CurrentState.Version = $Object2.enclosure.version

# if (@(@($Object1, $Object2, $Object3) | Sort-Object -Property { $_.enclosure.version } -Unique).Count -gt 1) {
if (@(@($Object2, $Object3) | Sort-Object -Property { $_.enclosure.version } -Unique).Count -gt 1) {
  $this.Log("x86 version: $($Object1.enclosure.version)")
  $this.Log("x64 version: $($Object2.enclosure.version)")
  $this.Log("arm64 version: $($Object3.enclosure.version)")
  throw 'Inconsistent versions detected'
}

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = $Object1.enclosure.url.Replace('snapshot-auto', 'snapshot')
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.enclosure.url.Replace('snapshot-auto', 'snapshot')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object3.enclosure.url.Replace('snapshot-auto', 'snapshot')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object2.releaseNotesLink
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("/html/body/h2[contains(text(), 'Changelog since')][1]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
