$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.yxfile.com.cn/')
Start-Sleep -Seconds 5

# Version
$this.CurrentState.Version = [regex]::Match(
  $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="home"]/div/div[1]/form/p[1]')).Text,
  '最新版本: ([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://static.youxiao.cn/yxfile/lastest.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # $Object1 = Invoke-WebRequest -Uri 'https://www.youxiao.cn/wordpress/index.php/yxfile/log/' | ConvertFrom-Html

    # try {
    #   $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//*[@id='post-930']/div[2]/ul[contains(./li/text(), '$($this.CurrentState.Version)')]")
    #   if ($ReleaseNotesTitleNode) {
    #     # ReleaseTime
    #     $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}年\d{1,2}月\d{1,2}日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    #     # ReleaseNotes (zh-CN)
    #     $this.CurrentState.Locale += [ordered]@{
    #       Locale = 'zh-CN'
    #       Key    = 'ReleaseNotes'
    #       Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ol[1]') | Get-TextContent | Format-Text
    #     }
    #   } else {
    #     $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
    #   }
    # } catch {
    #   $this.Log($_, 'Warning')
    # }

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
