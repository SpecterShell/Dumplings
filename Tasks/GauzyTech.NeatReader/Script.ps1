# International
$Object1 = Invoke-WebRequest -Uri 'https://www.neat-reader.com/download/start-download?target=windows' | ConvertFrom-Html
$Version1 = $Object1.SelectSingleNode('/html/body/input[2]').Attributes['value'].Value.Trim()

# Chinese
$Object2 = Invoke-WebRequest -Uri 'https://www.neat-reader.cn/downloads/windows' | ConvertFrom-Html
$Version2 = [regex]::Match(
  $Object2.SelectSingleNode('/html/body/div[3]/div/div/p[3]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

if ($Version1 -ne $Version2) {
  Write-Host -Object "Task $($Task.Name): Distinct versions detected" -ForegroundColor Yellow
  $Task.Config.Notes = '检测到不同的版本'
}

# Version
$Task.CurrentState.Version = $Version1

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://neat-reader-release.oss-cn-hongkong.aliyuncs.com/NeatReader Setup ${Version1}.exe"
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.SelectSingleNode('/html/body/div[3]/div/div/div[1]/a[1]').Attributes['href'].Value | ConvertTo-UnescapedUri
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $Version1 -eq $Version2 }) {
    New-Manifest
  }
}
