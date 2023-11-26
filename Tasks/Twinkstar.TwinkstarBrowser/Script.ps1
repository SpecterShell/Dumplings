$Object1 = Invoke-WebRequest -Uri 'https://www.twinkstar.com/' -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' | ConvertFrom-Html

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = $Object1.SelectSingleNode('//a[contains(@class, "download-win")]').Attributes['href'].Value
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl.Replace('.exe', '32.exe')
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'v([\d\.]+)').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.SelectSingleNode('//a[contains(@class, "download-win")]//div[@class="download-date"][2]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://bbs.twinkstar.com/forum.php?mod=viewthread&tid=4227' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='postmessage_14664']/*[contains(.//text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::*[contains(.//text(), "changelog")][1]').NextSibling; $Node.InnerText -cnotmatch '下载地址|- - - - -'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
