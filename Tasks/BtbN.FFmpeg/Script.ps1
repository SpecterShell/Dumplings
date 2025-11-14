$RepoOwner = 'BtbN'
$RepoName = 'FFmpeg-Builds'

$TargetDate = (Get-Date -AsUTC).AddDays(1).ToString('yyyy-MM-01').ToDateTime($null).AddDays(-1)

$Object1 = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases").Where({ $_.tag_name.Contains($TargetDate.ToString('yyyy-MM-dd')) }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^autobuild-'

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('win64') -and $_.name.Contains('-gpl') -and -not $_.name.Contains('shared') -and $_.name.Contains('N-') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
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
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('winarm64') -and $_.name.Contains('-gpl') -and -not $_.name.Contains('shared') -and $_.name.Contains('N-') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
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

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
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
    $this.MessageEnabled = $false
  }
  'Updated' {
    foreach ($License in @('GPL', 'LGPL')) {
      foreach ($Shared in @($false, $true)) {
        foreach ($Branch in @('master', '7.1', '8.0')) {
          $this.Config.WinGetIdentifier = "BtbN.FFmpeg.${License}$($Shared ? '.Shared' : '')$($Branch -eq 'master' ? '' : ".${Branch}")"

          $Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('win64') -and $_.name.Contains("-$($License.ToLower())") -and ($Shared -eq $_.name.Contains('shared')) -and ($Branch -eq 'master' ? $_.name.Contains('N-') : $_.name.Contains("n${Branch}")) }, 'First')[0]
          $this.CurrentState.RealVersion = $Branch -eq 'master' ? "$([regex]::Match($Asset.name, '(N-\d+-[a-zA-Z0-9]+)').Groups[1].Value)-$($TargetDate.ToString('yyyyMMdd'))" : "$([regex]::Match($Asset.name, '-n(\d+(?:\.\d+)+)').Groups[1].Value)-$($TargetDate.ToString('yyyyMMdd'))"
          $this.CurrentState.Installer = @(
            [ordered]@{
              Architecture         = 'x64'
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
          )

          $Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('winarm64') -and $_.name.Contains("-$($License.ToLower())") -and ($Shared -eq $_.name.Contains('shared')) -and ($Branch -eq 'master' ? $_.name.Contains('N-') : $_.name.Contains("n${Branch}")) }, 'First')[0]
          $this.CurrentState.Installer = @(
            [ordered]@{
              Architecture         = 'arm64'
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
          )

          try {
            $this.Submit()
          } catch {
            $_ | Out-Host
            $this.Log($_, 'Warning')
          }
        }
      }
    }
  }
  'Changed|Updated' {
    $this.Message()
  }
}
