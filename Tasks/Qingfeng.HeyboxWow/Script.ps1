$Object = Invoke-RestMethod -Uri 'https://accoriapi.xiaoheihe.cn/wow/check_new_version_v2/'

# Version
$Task.CurrentState.Version = $Object.result.version_list[0].Version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.result.version_list[0].DownloadPath
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.result.version_list[0].PublishTime | ConvertFrom-UnixTimeMilliseconds

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = [regex]::Matches($Object.result.version_list[0].VersionLog, '(?<=<li>).+?(?=</li>)').Value | Format-Text | ConvertTo-UnorderedList
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
