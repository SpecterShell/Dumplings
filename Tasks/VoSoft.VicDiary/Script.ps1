$RepoOwner = 'vo-soft'
$RepoName = 'vic-diary-release'

$Object1 = Invoke-RestMethod -Uri "https://gitee.com/api/v5/repos/${RepoOwner}/${RepoName}/releases/latest" -Authentication Bearer -Token (ConvertTo-SecureString -String $Global:DumplingsSecret.GiteeToken -AsPlainText)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://gitee.com/${RepoOwner}/${RepoName}/releases/tag/$($Object1.tag_name)"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri "https://gitee.com/api/v5/repos/${RepoOwner}/${RepoName}/releases/tags/v$($this.CurrentState.Version)" -Authentication Bearer -Token (ConvertTo-SecureString -String $Global:DumplingsSecret.GiteeToken -AsPlainText)

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.created_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://gitee.com/${RepoOwner}/${RepoName}/releases/tag/$($Object2.tag_name)"
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
