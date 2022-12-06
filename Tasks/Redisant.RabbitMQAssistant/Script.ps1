$Object = Invoke-RestMethod -Uri 'https://www.redisant.com/rta/activate/checkUpdate'
# $Object = Invoke-RestMethod -Uri 'https://www.redisant.cn/rta/activate/checkUpdate'

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.downloadUrl
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.enDescribes | Format-Text | ConvertTo-UnorderedList
}
# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.describes | Format-Text | ConvertTo-UnorderedList
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
