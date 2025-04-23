$RepoOwner = 'element-hq'
$RepoName = 'element-desktop'

# x64
$Object1 = Invoke-WebRequest -Uri 'https://packages.element.io/desktop/update/win32/x64/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# arm64
$Object2 = Invoke-WebRequest -Uri 'https://packages.element.io/desktop/update/win32/arm64/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

if ($Object1.Version -ne $Object2.Version) {
  $this.Log("x64 version: $($Object1.Version)")
  $this.Log("arm64 version: $($Object2.Version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://packages.element.io/desktop/install/win32/x64/Element Setup $($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://packages.element.io/desktop/install/win32/arm64/Element Setup $($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/v$($this.CurrentState.Version)"

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.body | Convert-MarkdownToHtml | Get-TextContent | Format-Text
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
