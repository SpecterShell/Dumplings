$RepoOwner = 'Aleksoid1978'
$RepoName = 'MPC-BE'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('installer') -and $_.name.Contains('x86') })[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "MPC-BE.$($this.CurrentState.Version).x86.exe"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('installer') -and $_.name.Contains('x64') })[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "MPC-BE.$($this.CurrentState.Version).x64.exe"
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.html_url
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = (Invoke-RestMethod -Uri "https://github.com/${RepoOwner}/${RepoName}/releases.atom").Where({ $_.id.EndsWith($this.CurrentState.Version) })[0]

      if ($Object2.content.'#text' -ne 'No content.') {
        # ReleaseNotes (en-US)
        # Markdig is buggy on the markdown release notes from GitHub API. Use HTML one from GitHub RSS instead
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.content.'#text' | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
