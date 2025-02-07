$Prefix = 'https://get.wiz.cn/x/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.wiz.cn/as/blogs/wiznew.html').result.markdown | Convert-MarkdownToHtml
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")

      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}-\d{2}-\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
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
