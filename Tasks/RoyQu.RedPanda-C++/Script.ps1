$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/royqh1979/RedPanda-CPP/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('win32') -and $_.name -match 'MinGW' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('win64') -and $_.name -match 'MinGW' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

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

    # try {
    #   $Object2 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/royqh1979/RedPanda-CPP/master/NEWS.md' | Convert-MarkdownToHtml

    #   $ReleaseNotesTitleNode = $Object2.SelectSingleNode("./p[text()='Red Panda C++ Version $($this.CurrentState.Version)']")
    #   if ($ReleaseNotesTitleNode) {
    #     $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'p' -and $Node.InnerText.Contains('Red Panda C++ Version')); $Node = $Node.NextSibling) { $Node }
    #     # ReleaseNotes (en-US)
    #     $this.CurrentState.Locale += [ordered]@{
    #       Locale = 'en-US'
    #       Key    = 'ReleaseNotes'
    #       Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    #     }
    #   } else {
    #     $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    #   }
    # } catch {
    #   $_ | Out-Host
    #   $this.Log($_, 'Warning')
    # }

    try {
      $Object3 = Invoke-RestMethod -Uri "https://gitee.com/royqh1979/redpandacpp/raw/master/sources/main/content/blog/version.$($this.CurrentState.Version).md" | Convert-MarkdownToHtml

      $ReleaseNotesCNTitleNode = $Object3.SelectSingleNode("/h4[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNTitleNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://royqh.net/redpandacpp/blog/'
      }

      $Object4 = Invoke-RestMethod -Uri 'https://gitee.com/royqh1979/redpandacpp/raw/public/blog/index.xml'

      $ReleaseNotesUrlCNObject = $Object4.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')
      if ($ReleaseNotesUrlCNObject) {
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrlCNObject[0].link | ConvertTo-Https
        }
      } else {
        $this.Log("No ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
