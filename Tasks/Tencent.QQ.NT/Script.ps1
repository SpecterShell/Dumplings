$Object1 = Invoke-RestMethod -Uri 'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js' | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.ntDownloadUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = $Object1.ntDownloadX64Url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)_x64\.exe').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.ntPublishTime | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsQQVersionList.js' | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json).ntLogs | Where-Object -FilterScript { $_.version.EndsWith($Object1.ntVersion) }

    try {
      if ($Object2) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.features.text | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
