$RepoOwner = 'nodejs'
$RepoName = 'node'

$Object1 = (Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json') |
  Where-Object -FilterScript { $_.lts } |
  # Sort-Object -Property { $_.version -replace '\d+', { $_.Value.PadLeft(20) } } |
  Select-Object -First 1

# Version
$this.CurrentState.Version = $Object1.version -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://nodejs.org/dist/v$($this.CurrentState.Version)/node-v$($this.CurrentState.Version)-x86.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://nodejs.org/dist/v$($this.CurrentState.Version)/node-v$($this.CurrentState.Version)-x64.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://nodejs.org/dist/v$($this.CurrentState.Version)/node-v$($this.CurrentState.Version)-arm64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.date | Get-Date -Format 'yyyy-MM-dd'

      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'Documentations'
        Value = @(
          [ordered]@{
            DocumentLabel = 'Learn'
            DocumentUrl   = 'https://nodejs.org/learn/'
          }
          [ordered]@{
            DocumentLabel = 'Documentation'
            DocumentUrl   = "https://nodejs.org/docs/v$($this.CurrentState.Version)/api/"
          }
          [ordered]@{
            DocumentLabel = 'About'
            DocumentUrl   = 'https://nodejs.org/about/'
          }
        )
      }

      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '学习'
            DocumentUrl   = 'https://nodejs.org/zh-cn/learn/'
          }
          [ordered]@{
            DocumentLabel = '文档'
            DocumentUrl   = "https://nodejs.org/docs/v$($this.CurrentState.Version)/api/"
          }
          [ordered]@{
            DocumentLabel = '关于'
            DocumentUrl   = 'https://nodejs.org/zh-cn/about/'
          }
        )
      }

      # LicenseUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'LicenseUrl'
        Value = "https://github.com/nodejs/node/blob/v$($this.CurrentState.Version)/LICENSE"
      }

      # PublisherSupportUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'PublisherSupportUrl'
        Value = "https://github.com/nodejs/node/blob/v$($this.CurrentState.Version)/.github/SUPPORT.md"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/v$($this.CurrentState.Version)"

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.body | Convert-MarkdownToHtml -Extensions $MarkdigSoftlineBreakAsHardlineExtension | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://github.com/${RepoOwner}/${RepoName}/releases/tag/v$($this.CurrentState.Version)"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }
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
