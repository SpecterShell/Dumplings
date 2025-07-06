$Object1 = Invoke-WebRequest -Uri 'https://openvpn.net/community/'

# Installer
# x86
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('x86') } catch {} }, 'First')[0].href
}
$VersionX86 = [regex]::Match($InstallerUrlX86, '(\d+(?:\.\d+)+-I\d+)').Groups[1].Value
# x64
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('amd64') } catch {} }, 'First')[0].href
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '(\d+(?:\.\d+)+-I\d+)').Groups[1].Value
# arm64
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrlARM64 = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('arm64') } catch {} }, 'First')[0].href
}
$VersionARM64 = [regex]::Match($InstallerUrlARM64, '(\d+(?:\.\d+)+-I\d+)').Groups[1].Value

if (@(@($VersionX86, $VersionX64, $VersionARM64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("arm64 version: ${VersionARM64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64
$ShortVersion = $this.CurrentState.Version -replace '-I\d+$'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      $RepoOwner = 'OpenVPN'
      $RepoName = 'openvpn'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://github.com/${RepoOwner}/${RepoName}/releases"
      }

      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/v${ShortVersion}"

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object2.html_url
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
