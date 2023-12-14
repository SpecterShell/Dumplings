$Object = Invoke-RestMethod -Uri 'https://www.redisant.com/da/activate/checkUpdate'
# $Object = Invoke-RestMethod -Uri 'https://www.redisant.cn/da/activate/checkUpdate'

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
