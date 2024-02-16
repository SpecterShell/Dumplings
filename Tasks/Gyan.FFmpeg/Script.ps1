$RepoOwner = 'GyanD'
$RepoName = 'codexffmpeg'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('full') -and -not $_.name.Contains('shared') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\bin\ffmpeg.exe"
      PortableCommandAlias = 'ffmpeg'
    }
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\bin\ffplay.exe"
      PortableCommandAlias = 'ffplay'
    }
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase)\bin\ffprobe.exe"
      PortableCommandAlias = 'ffprobe'
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = "https://raw.githubusercontent.com/FFmpeg/FFmpeg/release/$($this.CurrentState.Version.Split('.')[0..1] -join '.')/Changelog"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-RestMethod -Uri $ReleaseNotesUrl

      $ReleaseNotesObject = ($Object2 -split '(?m)(?=^version [\d\.]+:?\n)').Where({ $_.Contains($this.CurrentState.Version) }, 'First')[0]
      if ($ReleaseNotesObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject -creplace '^version [\d\.]+:?\n' | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
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
