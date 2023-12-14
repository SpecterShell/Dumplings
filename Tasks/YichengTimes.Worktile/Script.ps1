$Object = Invoke-RestMethod -Uri 'https://worktile.com/api/mobile/version/check?type=windows'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.data.path
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'worktile-(\d+\.\d+\.\d+)').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.data.date | ConvertFrom-UnixTimeSeconds

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.desc | Format-Text
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
