$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest'

# Version
$Version = $Object1.tag_name -replace '^v'
$this.CurrentState.Version = $Version.Replace('-', '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('dll') -and $_.name.Contains('Q16') -and -not $_.name.Contains('HDRI') -and $_.name.Contains('x86') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  ProductCode   = "ImageMagick $($Version.Split('-')[0]) Q16 (32-bit)_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('dll') -and $_.name.Contains('Q16') -and -not $_.name.Contains('HDRI') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  ProductCode   = "ImageMagick $($Version.Split('-')[0]) Q16 (64-bit)_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('dll') -and $_.name.Contains('Q16') -and -not $_.name.Contains('HDRI') -and $_.name.Contains('arm64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  ProductCode   = "ImageMagick $($Version.Split('-')[0]) Q16 (arm64)_is1"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://github.com/ImageMagick/Website/blob/HEAD/ChangeLog.md'
      }

      $Object3 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/ImageMagick/Website/HEAD/ChangeLog.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("/h2[contains(.//text(), '${Version}')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
          Value  = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
