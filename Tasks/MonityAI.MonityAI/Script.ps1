$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/kamilmm21/monity-desktop-releases/releases/latest'

# Version
# Monity-AI-windows.exe is the mutable alias the download page links, and the .blockmap, .dmg and
# .zip assets are delta or macOS payloads, so only the versioned Windows x64 setup is selected.
# electron-builder writes that file name's version straight into ARP DisplayVersion.
$Asset = $Object1.assets.Where({ $_.name -match '^Monity-AI-[0-9][0-9a-zA-Z.\-]*-x64\.exe$' }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide a versioned Windows x64 installer.'
}
$this.CurrentState.Version = [regex]::Match($Asset.name, '^Monity-AI-(.+)-x64\.exe$').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Asset.browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotes (en-GB) and ReleaseNotesUrl (en-GB)
      # The publisher writes the release body in British English; the trailing Download section only
      # lists the asset names and install steps, so it is dropped at the next h3 boundary.
      if ([string]::IsNullOrWhiteSpace($Object1.body)) {
        $this.Log("No ReleaseNotes (en-GB) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $Skip = $false
        $SkippedHeadingLevel = 0
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match 'Download'
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
          }
          if (-not $Skip) { $Node }
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-GB'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-GB'
          Key    = 'ReleaseNotesUrl'
          Value  = [string]$Object1.html_url
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
