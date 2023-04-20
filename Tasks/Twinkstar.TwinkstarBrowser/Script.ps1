$Object1 = Invoke-WebRequest -Uri 'https://www.twinkstar.com/' -UserAgent 'Mozilla/5.0 (Windows NT 10.0)' | ConvertFrom-Html
$Object2 = Invoke-WebRequest -Uri 'https://www.twinkstar.com/' -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' | ConvertFrom-Html

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = $Object1.SelectSingleNode('//a[contains(@class, "download-win")]').Attributes['href'].Value
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object2.SelectSingleNode('//a[contains(@class, "download-win")]').Attributes['href'].Value
}

# Version
$VersionX86 = [regex]::Match($InstallerUrlx86, 'v([\d\.]+)').Groups[1].Value
$Task.CurrentState.Version = $VersionX64 = [regex]::Match($InstallerUrlx64, 'v([\d\.]+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  Write-Host -Object "Task $($Task.Name): The versions are different between the architectures"
  $Task.Config.Notes = '各个架构的版本号不相同'
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object2.SelectSingleNode('//a[contains(@class, "download-win")]//div[@class="download-date"][2]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object3 = Invoke-WebRequest -Uri 'https://bbs.twinkstar.com/forum.php?mod=viewthread&tid=4227' | ConvertFrom-Html

    try {
      $ReleaseNotesTitle = $Object3.SelectSingleNode('//*[@id="postmessage_14664"]/font[1]').InnerText
      if ($ReleaseNotesTitle.Contains($Task.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object3.SelectNodes('//*[@id="postmessage_14664"]/font[contains(.//text(), "changelog")][1]/following-sibling::node()[count(.|//*[@id="postmessage_14664"]/font[contains(.//text(), "下载地址")]/preceding-sibling::node())=count(//*[@id="postmessage_14664"]/font[contains(.//text(), "下载地址")]/preceding-sibling::node())]') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $VersionX86 -eq $VersionX64 }) {
    New-Manifest
  }
}
