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
$this.CurrentState.Version = $Object.win.package.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.win.install.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match($Object.win.install.description[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.win.install.multi_lang_description.en_US | Select-Object -Skip 1 | Format-Text
}
# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.win.install.description | Select-Object -Skip 1 | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
