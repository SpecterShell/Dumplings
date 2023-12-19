# International
$Object1 = Invoke-WebRequest -Uri 'https://www.neat-reader.com/download/start-download?target=windows' | ConvertFrom-Html
$Version1 = $Object1.SelectSingleNode('/html/body/input[2]').Attributes['value'].Value.Trim()

# Chinese
$Object2 = Invoke-WebRequest -Uri 'https://www.neat-reader.cn/downloads/windows' | ConvertFrom-Html
$Version2 = [regex]::Match(
  $Object2.SelectSingleNode('/html/body/div[3]/div/div/p[3]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

$Identical = $true
if ($Version1 -ne $Version2) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
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

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $Task.Submit()
  }
}
