$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/oop7/rhashsum/releases/latest'

# The release tag carries the wrong number (v4.5.7 for the 4.7.0 build), so the version comes
# from the MSI file name instead.
$Object2 = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('x64') }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object2.name, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object2.browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectNodes('./h1|./h2')[0]
        # Skip the sponsorship paragraph that precedes the first change heading.
        $Skip = $true
        $ReleaseNotesNodes = @(
          $ReleaseNotesTitleNode
          for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node; $Node = $Node.NextSibling) {
            if ($Skip -and $Node.Name -match '^h[1-6]$') { $Skip = $false }
            if (-not $Skip) { $Node }
          }
        )

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
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
