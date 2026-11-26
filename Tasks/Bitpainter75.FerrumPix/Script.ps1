$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/Bitpainter75/FerrumPix/releases?per_page=100'

# Everything is published under the moving "latest" tag and the build number lives in the
# asset name, never in the tag. Once the tag moves on, the release keeps its assets under its
# version tag, so the newest release that still carries a Windows installer is the current one.
$VersionedReleases = foreach ($Release in $Object1) {
  $Asset = $Release.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'Setup' }, 'First')
  if (-not $Release.draft -and -not $Release.prerelease -and $Asset) {
    [pscustomobject]@{
      Release = $Release
      Asset   = $Asset[0]
      Version = $Asset[0].name -replace '^FerrumPix-(.+)-win-x64-Setup\.exe$', '$1'
    }
  }
}
if (-not $VersionedReleases) {
  throw 'No Windows installer was found in the releases of Bitpainter75/FerrumPix.'
}

$Object2 = $VersionedReleases | Sort-Object -Property { [ChunkVersion]$_.Version } -Bottom 1

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object2.Asset.browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.Release.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object2.Release.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.Release.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object2.Release.html_url
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

    if (-not $this.Status.Contains('New')) {
      # The newest build is only reachable through the moving "latest" tag, so the previous
      # version's manifest keeps a URL that dies as soon as the tag moves on. Once the release
      # has been archived under its version tag, rewrite that manifest to the stable address.
      $this.CurrentState = $this.LastState
      $this.CurrentState.Installer = @(
        [ordered]@{
          Architecture  = 'x64'
          InstallerType = 'nullsoft'
          InstallerUrl  = "https://github.com/Bitpainter75/FerrumPix/releases/download/$($this.CurrentState.Version)/FerrumPix-$($this.CurrentState.Version)-win-x64-Setup.exe"
        }
      )
      $this.ResetMessage()
      $this.Config.IgnorePRCheck = $true
      try {
        $this.Submit()
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }
    }
  }
}
