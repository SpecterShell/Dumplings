$Object1 = Invoke-WebRequest -Uri 'https://browser.360.cn/browser_download_link.js'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [regex]::Match($Object1.Content, "EEX:\s*'([^']+)'").Groups[1].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '_(\d+\.\d+\.\d+\.\d+)[_.]').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://bbs.360.cn/thread-16169101-1-1.html' | ConvertFrom-Html

      $Today = Get-Date -Format 'yyyy.M.d'
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//td[@id='postmessage_119526099']/text()[contains(., '$Today')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.InnerText -notmatch '(20\d{2}\.\d{1,2}\.\d{1,2})'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
