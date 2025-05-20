$Object1 = Invoke-RestMethod -Uri 'https://api.tabulareditor.com/UpgradeCheck'

# Version
$this.CurrentState.Version = $Object1.latest

# RealVersion
$this.CurrentState.RealVersion = $Object1.shortName

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://cdn.tabulareditor.com/files/TabularEditor.$($this.CurrentState.Version).x86.Net8.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://cdn.tabulareditor.com/files/TabularEditor.$($this.CurrentState.Version).x64.Net8.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://docs.tabulareditor.com/te3/other/release-notes'
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = "https://docs.tabulareditor.com/te3/other/release-notes/$($this.CurrentState.RealVersion.Replace('.', '_')).html"
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode('//*[@id="conceptual-content"]/h2[1]')
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
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
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log("The WinGet package needs to be updated to the version $($this.CurrentState.Version.Split('.')[0])", 'Error')
    } else {
      $this.Submit()
    }
  }
}
