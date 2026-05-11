$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/WangQrkkk/PaperQuay/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace 'app-' -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  Architecture    = 'x64'
  InstallerType   = 'wix'
  InstallerUrl    = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('x64') -and $_.name -match 'en-US' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerType   = 'wix'
  InstallerUrl    = $Object1.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('x64') -and $_.name -match 'zh-CN' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'

        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectNodes('./h2').Where({ $_.InnerText -notmatch "[${CJK}]" -and $_.InnerText -match 'Included' }, 'First')
        $ReleaseNotesCNTitleNode = $ReleaseNotesObject.SelectNodes('./h2').Where({ $_.InnerText -match "[${CJK}]" -and $_.InnerText -match '本次版本包含' }, 'First')
        if ($ReleaseNotesTitleNode -and $ReleaseNotesCNTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode[0].NextSibling; $Node -and $Node.Name -notin @('h1', 'h2', 'hr'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode[0].NextSibling; $Node -and $Node.Name -notin @('h1', 'h2', 'hr'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
