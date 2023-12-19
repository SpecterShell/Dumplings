$Object = Invoke-RestMethod -Uri 'https://www.xljsci.com/whale/api/client/version' -Method Post

# Version
$this.CurrentState.Version = $Version = $Object.data.showVersion

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = ($Object.data.intro | ConvertFrom-Html | Get-TextContent).Split("`n") | Select-Object -Skip 1 | Format-Text
}

$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.xljsci.com/download.html')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//div[starts-with(@class, "windowbox")]/a')).GetAttribute('href') | ConvertTo-UnescapedUri
}

if (!$InstallerUrl.Contains($Version)) {
  throw "Task $($this.Name): The InstallerUrl`n${InstallerUrl}`ndoesn't contain version $($Version)"
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match(
  $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//div[starts-with(@class, "windowbox")]/p[2]')).Text,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $this.CurrentState.RealVersion = Get-TempFile -Uri $InstallerUrl | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
