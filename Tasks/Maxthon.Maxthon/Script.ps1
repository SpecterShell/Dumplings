# International x64
$Object1 = (Invoke-RestMethod -Uri 'https://updater.maxthon.com/mx6/com/updater.json').maxthon | Where-Object -Property 'channels' -Contains -Value 'stable'
# International x86
$Object2 = (Invoke-RestMethod -Uri 'https://updater.maxthon.com/mx6/com/updater_x86.json').maxthon | Where-Object -Property 'channels' -Contains -Value 'stable'
# Chinese x64
$Object3 = (Invoke-RestMethod -Uri 'https://updater.maxthon.cn/mx6/cn/updater.json').maxthon | Where-Object -Property 'channels' -Contains -Value 'stable'
# Chinese x86
$Object4 = (Invoke-RestMethod -Uri 'https://updater.maxthon.cn/mx6/cn/updater_x86.json').maxthon | Where-Object -Property 'channels' -Contains -Value 'stable'

if ((@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property 'version' -Unique).Length -gt 1) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Task.Config.Notes = '检测到不同的版本'
}

# Version
$Task.CurrentState.Version = $Object1.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.url
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x86'
  InstallerUrl    = $Object4.url
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object3.url
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and (@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property 'version' -Unique).Length -eq 1 }) {
    $Task.Submit()
  }
}
