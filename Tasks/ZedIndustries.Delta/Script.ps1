$Object1 = Invoke-RestMethod -Uri 'https://delta.dev/api/releases/stable/latest/asset?asset=delta&os=windows&arch=x86_64'
$Object2 = Invoke-RestMethod -Uri 'https://delta.dev/api/releases/stable/latest/asset?asset=delta&os=windows&arch=aarch64'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'burn'
  InstallerUrl  = $Object1.url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'burn'
  InstallerUrl  = $Object2.url | ConvertTo-UnescapedUri
}

if ($Object1.version -ne $Object2.version) {
  $this.Log("Inconsistent versions: x64: $($Object1.version), arm64: $($Object2.version)", 'Error')
  return
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://delta.dev/docs/whats-in-the-latest'
      }

      $ReleaseNotesDocument = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesDocument.SelectSingleNode("//h2[contains(@id, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'h2' -and $Node.Attributes.Contains('id') -and $Node.Attributes['id'].Value -match '^\d+(?:\.\d+)+$'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
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
