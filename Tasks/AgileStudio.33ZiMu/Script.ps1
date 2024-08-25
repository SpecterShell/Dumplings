$Object1 = Invoke-WebRequest -Uri 'https://www.33subs.com/download' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('//*[@id="app"]/div[2]/div/h1/div').InnerText, 'V([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download-win"]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl('https://zm.agilestudio.cn/changelog')

      $ReleaseNotesNode = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//article/div[./h1/span/text()='V$($this.CurrentState.Version)']"))
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNode.FindElement([OpenQA.Selenium.By]::XPath('./ol')).Text | ConvertTo-OrderedList | Format-Text
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
