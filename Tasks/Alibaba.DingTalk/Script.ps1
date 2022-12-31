# 自动更新源
$Object1 = Invoke-WebRequest -Uri 'https://im.dingtalk.com/manifest/new/release_windows_vista_later_all.json' | Read-ResponseContent | ConvertFrom-Json
# 手动更新源
$Object2 = Invoke-WebRequest -Uri 'https://im.dingtalk.com/manifest/new/release_windows_vista_later_manual_lowpriority.json' | Read-ResponseContent | ConvertFrom-Json
# 下载源
$Object3 = Invoke-WebRequest -Uri 'https://im.dingtalk.com/manifest/new/website/vista_later.json' | Read-ResponseContent | ConvertFrom-Json

$Object = @($Object1, $Object2, $Object3) |
  Sort-Object -Property { $_.win.package.version -creplace '\d+', { $_.Value.PadLeft(20) } } -Descending |
  Select-Object -First 1

# Version
$Task.CurrentState.Version = $Object.win.package.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.win.install.url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($Object.win.install.description[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.win.install.multi_lang_description.en_US | Select-Object -Skip 1 | Format-Text
}
# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.win.install.description | Select-Object -Skip 1 | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
