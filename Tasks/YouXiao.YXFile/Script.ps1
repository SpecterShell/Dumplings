$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.yxfile.com.cn/')

# Version
$Task.CurrentState.Version = [regex]::Match(
  $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="home"]/div/div[1]/form/p[1]')).Text,
  '最新版本: ([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="home"]/div/div[1]/form/a')).GetAttribute('href')
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # $Object = Invoke-WebRequest -Uri 'https://www.youxiao.cn/wordpress/index.php/yxfile/log/' | ConvertFrom-Html

    # try {
    #   $ReleaseNotesTitleNode = $Object.SelectSingleNode("//*[@id='post-930']/div[2]/ul[contains(./li/text(), '$($Task.CurrentState.Version)')]")
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
    #     $Task.Logging("No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
    #   }
    # } catch {
    #   $Task.Logging($_, 'Warning')
    # }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
