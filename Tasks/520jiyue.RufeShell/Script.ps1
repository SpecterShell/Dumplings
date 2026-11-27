$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/520jiyue/RufeShell/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
foreach ($Architecture in @('x64', 'arm64')) {
  $Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'windows' -and $_.name.Contains($Architecture) -and $_.name -match 'setup' -and $_.name -notmatch 'portable|update' }, 'First')[0]
  if (-not $Asset) {
    $this.Log("No Windows $($Architecture) setup asset for version $($this.CurrentState.Version)", 'Warning')
    continue
  }
  $this.CurrentState.Installer += [ordered]@{
    Architecture  = $Architecture
    InstallerType = 'nullsoft'
    InstallerUrl  = $Asset.browser_download_url | ConvertTo-UnescapedUri
  }
}

if (-not $this.CurrentState.Installer) {
  throw 'The latest release does not provide a Windows setup installer.'
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

    # Every release body only describes the platforms and the published files, so link to it
    # instead of publishing the same text as ReleaseNotes for each version.
    # ReleaseNotesUrl (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotesUrl'
      Value  = [string]$Object1.html_url
    }
    # ReleaseNotesUrl (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotesUrl'
      Value  = [string]$Object1.html_url
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
