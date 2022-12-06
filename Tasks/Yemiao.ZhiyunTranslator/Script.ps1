$Content1 = Invoke-WebRequest -Uri 'https://free.zhiyunwenxian.cn/zy/UpdateData.txt' | Read-ResponseContent
$Content2 = Invoke-WebRequest -Uri 'https://free.zhiyunwenxian.cn/zy/UpdateURL.txt' | Read-ResponseContent

# Version
$Task.CurrentState.Version = ($Content1 | Split-LineEndings)[0].Trim()

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Content2.Trim()
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($Content1, '(\d{4}年\d{1,2}月\d{1,2}日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = [regex]::Match($Content1, '更新内容：.*\n+((?:.+\n)+)').Groups[1].Value | Format-Text
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
