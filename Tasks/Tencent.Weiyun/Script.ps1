# Download
$Object1 = Invoke-RestMethod -Uri 'https://jsonschema.qpic.cn/2993ffb0f5d89de287319113301f3fca/179b0d35c9b088e5e72862a680864254/config'
# Upgrade x64
$Prefix2 = 'https://dldir1v6.qq.com/weiyun/electron-update/release/x64/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix2 -Locale 'zh-CN'
# Upgrade x86
$Prefix3 = 'https://dldir1v6.qq.com/weiyun/electron-update/release/win32/'
$Object3 = Invoke-RestMethod -Uri "${Prefix3}latest-win32.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix3 -Locale 'zh-CN'

if ((Compare-Version -ReferenceVersion $Object1.electron_win64.version -DifferenceVersion $Object2.Version) -gt 0) {
  if ($Object2.Version -ne $Object3.Version) {
    $Task.Logging('Distinct versions detected', 'Warning')
    $Task.Config.Notes = '检测到不同的版本'
  } else {
    $Identical = $True
  }

  $Task.CurrentState = $Object2
  $Task.CurrentState.Installer = $Object3.Installer + $Task.CurrentState.Installer
  $Task.CurrentState.Installer.ForEach({ $_.InstallerUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com') })
} else {
  if ($Object1.electron_win64.version -ne $Object1.electron_win32.version) {
    $Task.Logging('Distinct versions detected', 'Warning')
    $Task.Config.Notes = '检测到不同的版本'
  } else {
    $Identical = $True
  }

  # Version
  $Task.CurrentState.Version = $Object1.electron_win64.version

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $Object1.electron_win32.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
  }
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $Object1.electron_win64.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
  }

  # ReleaseTime
  $Task.CurrentState.ReleaseTime = $Object1.electron_win64.date | Get-Date -Format 'yyyy-MM-dd'
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
