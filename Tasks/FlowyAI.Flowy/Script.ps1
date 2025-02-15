$Prefix = 'https://download.flowygpt.cn/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl('https://www.flowyaipc.com/download')

      $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('/html/body/div[2]/div/button')).Click()
      $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('/html/body/div[2]/div/div/button[1]')).Click()
      $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//h3[contains(., '$($this.CurrentState.Version)')]")).Click()
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//h3[contains(., '$($this.CurrentState.Version)')]/following-sibling::*")).GetAttribute('innerHTML') | ConvertFrom-Html | Get-TextContent | Format-Text
      }

      $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('/html/body/div[2]/div/button')).Click()
      $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('/html/body/div[2]/div/div/button[2]')).Click()
      $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//h3[contains(., '$($this.CurrentState.Version)')]")).Click()
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//h3[contains(., '$($this.CurrentState.Version)')]/following-sibling::*")).GetAttribute('innerHTML') | ConvertFrom-Html | Get-TextContent | Format-Text
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
