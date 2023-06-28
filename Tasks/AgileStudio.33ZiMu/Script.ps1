$Prefix = 'https://oss.agilestudio.cn/app/zimu/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $EdgeDriver.Navigate().GoToUrl('https://zm.agilestudio.cn/changelog')

    try {
      $ReleaseNotesNode = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//article/div[./h1/span/text()='V$($Task.CurrentState.Version.Split('.')[0, 1] -join '.')']"))
      # ReleaseNotes (zh-CN)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNode.FindElement([OpenQA.Selenium.By]::XPath('./ol')).Text | ConvertTo-OrderedList | Format-Text
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
