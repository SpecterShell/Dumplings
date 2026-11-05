$Object1 = Invoke-RestMethod -Uri 'https://api.meta.ai/muse-code/channels/muse-stable'
$Object2 = Invoke-RestMethod -Uri $Object1.manifest_url

# Version
$this.CurrentState.Version = $Object1.version
$this.CurrentState.Version = '1.4.13'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'portable'
  InstallerUrl  = $Object2.artifacts.x86_windows.url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'portable'
  InstallerUrl  = $Object2.artifacts.aarch64_windows.url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesDocument = Invoke-WebRequest -Uri 'https://dev.meta.ai/docs/muse-code/changelog' | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesDocument.SelectSingleNode("//article//h2[normalize-space(.)='$($this.CurrentState.Version -replace '-.*$')']")
      if ($ReleaseNotesTitleNode) {
        # Remove prefice of <li> elements
        $ReleaseNotesDocument.SelectNodes('//article//li/span[2]/preceding-sibling::span[1]').ForEach({ $_.Remove() })
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
