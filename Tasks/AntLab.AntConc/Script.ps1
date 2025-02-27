$Object1 = Invoke-WebRequest -Uri 'https://www.laurenceanthony.net/software/antconc/'

# Installer
$Link = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('AntConc4') } catch {} }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://www.laurenceanthony.net/software/antconc/' $Link.href
}

# Version
$this.CurrentState.Version = [regex]::Match($Link.outerHTML, '\((\d+(?:\.\d+)+)\)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = Join-Uri $this.CurrentState.Installer[0].InstallerUrl 'version_history.pdf'
      }

      # LicenseUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'LicenseUrl'
        Value = Join-Uri $this.CurrentState.Installer[0].InstallerUrl 'license.pdf'
      }
      # CopyrightUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'CopyrightUrl'
        Value = Join-Uri $this.CurrentState.Installer[0].InstallerUrl 'license.pdf'
      }

      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'Documentations'
        Value = @(
          [ordered]@{
            DocumentLabel = 'Help'
            DocumentUrl   = Join-Uri $this.CurrentState.Installer[0].InstallerUrl 'help.pdf'
          }
          [ordered]@{
            DocumentLabel = 'Downloadable Guides'
            DocumentUrl   = 'https://www.laurenceanthony.net/software/antconc/#downloadable-guides'
          }
          [ordered]@{
            DocumentLabel = 'Video Tutorials'
            DocumentUrl   = 'https://www.laurenceanthony.net/software/antconc/#video-tutorials'
          }
          [ordered]@{
            DocumentLabel = 'FAQ'
            DocumentUrl   = 'https://www.laurenceanthony.net/software/antconc/#frequently-asked-questions-faq'
          }
        )
      }
      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '帮助'
            DocumentUrl   = Join-Uri $this.CurrentState.Installer[0].InstallerUrl 'help.pdf'
          }
          [ordered]@{
            DocumentLabel = '可下载指南'
            DocumentUrl   = 'https://www.laurenceanthony.net/software/antconc/#downloadable-guides'
          }
          [ordered]@{
            DocumentLabel = '视频教程'
            DocumentUrl   = 'https://www.laurenceanthony.net/software/antconc/#video-tutorials'
          }
          [ordered]@{
            DocumentLabel = '常见问题'
            DocumentUrl   = 'https://www.laurenceanthony.net/software/antconc/#frequently-asked-questions-faq'
          }
        )
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
