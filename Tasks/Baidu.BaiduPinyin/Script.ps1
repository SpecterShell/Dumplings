$Object1 = Invoke-WebRequest -Uri 'https://shurufa.baidu.com/' | ConvertFrom-Html

# Installer
$InstallerUrl = $Object1.SelectSingleNode('//*[@id="downloadInfo"]/div[1]/a').Attributes['href'].Value
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="versionMsg"]').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://shurufa.baidu.com/update' | ConvertFrom-Html

    try {
      if ($Object2.SelectSingleNode('//*[@id="update_body"]/div/div/div[1]/span[2]').InnerText.Contains($Task.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('//*[@class="update-item-split"][1]/following::*[@class="update-item-con"][count(.|//*[@class="update-item-tit"][2]/preceding::*[@class="update-item-con"])=count(//*[@class="update-item-tit"][2]/preceding::*[@class="update-item-con"])]') | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
