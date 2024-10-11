$RepoOwner = 'BtbN'
$RepoName = 'FFmpeg-Builds'

$TargetDate = (Get-Date -AsUTC).AddDays(1).ToString('yyyy-MM-01').ToDateTime($null).AddDays(-1).ToString('yyyy-MM-dd')

$Object1 = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases").Where({ $_.tag_name.Contains($TargetDate) }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^autobuild-'

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('win64') -and $_.name.Contains('-lgpl') -and -not $_.name.Contains('shared') -and $_.name.Contains('n5.1') }, 'First')[0]
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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.html_url
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
