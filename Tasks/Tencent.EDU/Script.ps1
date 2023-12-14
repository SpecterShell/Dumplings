$Object = Invoke-RestMethod -Uri 'https://sas.qq.com/cgi-bin/ke_download_pcClient'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.result.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'EduInstall_([\d\.]+)_.+\.exe').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.result.publish_time | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.result.desc | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
