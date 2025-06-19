$VersionResponse = [string](Invoke-RestMethod -Method Get -Uri 'https://datovka.nic.cz/Version')

# Version
$this.CurrentState.Version = $VersionResponse.TrimStart('_').Trim()
# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://datovka.nic.cz/$($this.CurrentState.Version)/datovka-$($this.CurrentState.Version)-windows-x86.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://datovka.nic.cz/$($this.CurrentState.Version)/datovka-$($this.CurrentState.Version)-windows-x64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $InstallerHeaderResponse = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
      $this.CurrentState.ReleaseTime = [datetime]($InstallerHeaderResponse.Headers['Last-Modified'] | Get-Date).ToUniversalTime()

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://www.datovka.cz/cs/$($this.CurrentState.ReleaseTime.ToString("yyyy-MM-dd"))-datovka-$($this.CurrentState.Version).html"
      }

      # ReleaseNotes (cs-CZ)
      $ReleaseNotesResponse = Invoke-WebRequest -Uri $this.CurrentState.Locale[0].Value -Method Get | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesResponse.SelectSingleNode(".//div[@role='main']/h1")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (cs-CZ)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'cs-CZ'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
