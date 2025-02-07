$RepoOwner = 'siyuan-note'
$RepoName = 'siyuan'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('win') -and -not $_.name.Contains('arm64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('win') -and $_.name.Contains('arm64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions $MarkdigSoftlineBreakAsHardlineExtension
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not ($Node.Name -eq 'h2' -and $Node.InnerText.Contains('Download')); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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

    try {
      $Object2 = (Invoke-WebRequest -Uri 'https://siyuan-sync.b3logfile.com/apis/siyuan/version').Content | ConvertFrom-Json -AsHashtable

      if ($Object2.ver -eq $this.CurrentState.Version) {
        $Object3 = Invoke-RestMethod -Uri $Object2.release_zh_CN.Replace('ld246.com', 'ld246.com/api/v2') -Headers @{ Authorization = $Global:DumplingsSecret.LD246_TOKEN } -UserAgent "$([Microsoft.PowerShell.Commands.PSUserAgent].GetProperty('UserAgent', [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Static).GetValue($null)) Dumplings/3.0"

        $ReleaseNotesCNObject = $Object3.data.article.articleContent | ConvertFrom-Html
        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNObject.ChildNodes[0]; $Node -and -not ($Node.Name -eq 'h2' -and $Node.InnerText.Contains('下载')); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
        }

        # # ReleaseNotesUrl (zh-CN)
        # $this.CurrentState.Locale += [ordered]@{
        #   Locale = 'zh-CN'
        #   Key    = 'ReleaseNotesUrl'
        #   Value  = $ReleaseNotesUrlCN = $Object1.release_zh_CN
        # }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
