# x86
$Object1 = Invoke-RestMethod -Uri 'https://update.vivaldi.com/update/1.0/public/appcast.xml'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://update.vivaldi.com/update/1.0/public/appcast.x64.xml'

# Version
$this.CurrentState.Version = $Object2.enclosure.version

$Identical = $true
if ($Object1.enclosure.version -ne $Object2.enclosure.version) {
  $this.Log('Distinct versions detected', 'Warning')
  $this.Log("x86 version: $($Object1.enclosure.version)")
  $this.Log("x64 version: $($Object2.enclosure.version)")
  $Identical = $false
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.enclosure.url.Replace('stable-auto', 'stable')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.enclosure.url.Replace('stable-auto', 'stable')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object2.releaseNotesLink
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//body/h2[contains(text(), 'Changelog since')][1]")
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
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
