$Object = Invoke-RestMethod -Uri 'https://www.xljsci.com/whale/api/client/version' -Method Post

# Version
$Task.CurrentState.Version = $Version = $Object.data.showVersion

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = ($Object.data.intro | ConvertFrom-Html | Get-TextContent).Split("`n") | Select-Object -Skip 1 | Format-Text
}

$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.xljsci.com/download.html')

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//div[starts-with(@class, "windowbox")]/a')).GetAttribute('href') | ConvertTo-UnescapedUri
}

if (!$InstallerUrl.Contains($Version)) {
  throw "Task $($Task.Name): The InstallerUrl`n${InstallerUrl}`ndoesn't contain version $($Version)"
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//div[starts-with(@class, "windowbox")]/p[2]')).Text,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $InstallerUrl | Read-ProductVersionFromExe

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
