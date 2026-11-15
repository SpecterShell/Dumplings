$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/hungry-detective/downloadcraft/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  Scope         = 'user'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' -and $_.name -notmatch 'user' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  Scope         = 'machine'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' -and $_.name -notmatch 'user' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $Skip = $false
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not ($Node.Name -match '^h\d$' -and $Node.InnerText -match 'Earlier'); $Node = $Node.NextSibling) {
          if ($Node.Name -in @('h1', 'h2')) { $Skip = $Node.InnerText -match 'Install' }
          if (-not $Skip) { $Node }
        }
        # ReleaseNotes (en-GB)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-GB'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-GB) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-GB)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-GB'
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
