$EdgeDriver.Navigate().GoToUrl('https://www.yxcal.com/')

# Version
$Task.CurrentState.Version = [regex]::Match(
  $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="home"]/div/div[1]/form[1]/p[1]')).Text,
  '最新版本: ([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://static.youxiao.cn/yxcalendar/yxcalendar_v$($Task.CurrentState.Version).exe"
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # $Object = Invoke-WebRequest -Uri 'https://www.youxiao.cn/wordpress/index.php/yxcalendar/version-log/' | ConvertFrom-Html

    # try {
    #   $ReleaseNotesTitleNode = $Object.SelectSingleNode("//*[@id='post-350']/div[2]/ul[contains(./li/text(), '$($Task.CurrentState.Version)')]")
    #   if ($ReleaseNotesTitleNode) {
    #     # ReleaseTime
    #     $Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}年\d{1,2}月\d{1,2}日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    #     # ReleaseNotes (zh-CN)
    #     $Task.CurrentState.Locale += [ordered]@{
    #       Locale = 'zh-CN'
    #       Key    = 'ReleaseNotes'
    #       Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ol[1]') | Get-TextContent | Format-Text
    #     }
    #   } else {
    #     Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
    #   }
    # } catch {
    #   Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    # }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
