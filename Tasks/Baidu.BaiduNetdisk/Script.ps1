$Object = Invoke-RestMethod -Uri 'https://pan.baidu.com/disk/cmsdata?platform=guanjia'

# Version
$Task.CurrentState.Version = [regex]::Match($Object.list[0].version, '(\d+\.\d+\.\d+)\.\d+').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.list[0].url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.list[0].publish | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.list[0].detail.more | Format-Text | ConvertTo-OrderedList
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
