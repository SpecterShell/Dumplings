$RepoOwner = 'buxuku'
$RepoName = 'SmartSub'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name.Contains('no-cuda') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }

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
    $this.MessageEnabled = $false
  }
  'Updated' {
    $WinGetIdentifierPrefix = $this.Config.WinGetIdentifier

    $this.Config.WinGetIdentifier = "${WinGetIdentifierPrefix}.CPU"
    $this.CurrentState.Installer = @(
      [ordered]@{
        Architecture = 'x64'
        InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name.Contains('no-cuda') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
      }
    )

    try {
      $this.Submit()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Branch in @('11.8', '12.2', '12.4')) {
      foreach ($Optimized in @($false, $true)) {
        $this.Config.WinGetIdentifier = "${WinGetIdentifierPrefix}.CUDA.${Branch}$($Optimized ? '.Optimized' : '')"
        $this.CurrentState.Installer = @(
          [ordered]@{
            Architecture = 'x64'
            InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and ($_.name.Contains("_${Branch}") -and ($Optimized ? $_.name.Contains('optimized') : $_.name.Contains('generic'))) }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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
  'Changed|Updated' {
    $this.Message()
  }
}
