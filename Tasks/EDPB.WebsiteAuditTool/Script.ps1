$Object1 = Invoke-RestMethod -Uri 'https://code.europa.eu/api/v4/projects/615/releases/permalink/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

if ($this.CurrentState.Version -match 'a\d*$') {
  $this.Log("The version $($this.CurrentState.Version) is a pre-release version", 'Error')
  return
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.assets.links.Where({ $_.name.EndsWith('.exe') }, 'First')[0].url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.released_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.description)) {
        $ReleaseNotesObject = $Object1.description | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not $Node.InnerText.Contains('SHA2-256'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1._links.self
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
