$Prefix = 'https://oss.agilestudio.cn/app/zimu/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $EdgeDriver = Get-EdgeDriver
      $EdgeDriver.Navigate().GoToUrl('https://zm.agilestudio.cn/changelog')

      $ReleaseNotesNode = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//article/div[./h1/span/text()='V$($this.CurrentState.Version.Split('.')[0, 1] -join '.')']"))
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

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
