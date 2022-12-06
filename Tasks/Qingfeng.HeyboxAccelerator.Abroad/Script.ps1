$Object = Invoke-RestMethod -Uri 'https://accoriapi.xiaoheihe.cn/proxy/pc_has_new_version/?download_source=abroad'

# Version
$Task.CurrentState.Version = $Object.result.new_version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.result.url
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.result.change_log | ConvertFrom-Html | Get-TextContent | Format-Text
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
