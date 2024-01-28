$RepoOwner = 'GyanD'
$RepoName = 'codexffmpeg'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('full') -and -not $_.name.Contains('shared') })[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = "ffmpeg-$($this.CurrentState.Version)-full_build\bin\ffmpeg.exe"
      PortableCommandAlias = 'ffmpeg'
    }
    [ordered]@{
      RelativeFilePath     = "ffmpeg-$($this.CurrentState.Version)-full_build\bin\ffplay.exe"
      PortableCommandAlias = 'ffplay'
    }
    [ordered]@{
      RelativeFilePath     = "ffmpeg-$($this.CurrentState.Version)-full_build\bin\ffprobe.exe"
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

      $ReleaseNotesObject = ($Object2 -split '(?m)(?=^version [\d\.]+:?\n)').Where({ $_.Contains($this.CurrentState.Version) })[0]
      if ($ReleaseNotesObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject -creplace '^version [\d\.]+:?\n' | Format-Text
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
