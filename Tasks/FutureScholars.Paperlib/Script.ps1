$Prefix = 'https://distribution.paperlib.app/electron-win/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/GeoffreyChen777/paperlib/master/CHANGELOG_EN.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("./h2[contains(@id, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]{3} \d{1,2} \d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/GeoffreyChen777/paperlib/master/CHANGELOG_CN.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("./h2[contains(@id, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}/\d{2} \d{4})').Groups[1].Value,
          'dd/MM yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
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
