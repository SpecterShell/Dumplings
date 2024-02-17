$Object1 = Invoke-WebRequest -Uri 'https://www.twinkstar.com/' -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = $Object1.SelectSingleNode('//a[contains(@class, "download-win")]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl.Replace('.exe', '32.exe')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'v([\d\.]+)').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.SelectSingleNode('//a[contains(@class, "download-win")]//div[@class="download-date"][2]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://bbs.twinkstar.com/forum.php?mod=viewthread&tid=4227' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='postmessage_14664']/*[contains(.//text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::*[contains(.//text(), "changelog")][1]').NextSibling; $Node.InnerText -cnotmatch '下载地址|- - - - -'; $Node = $Node.NextSibling) { $Node }
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

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
