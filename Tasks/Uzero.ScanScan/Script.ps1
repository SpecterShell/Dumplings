$Object = Invoke-RestMethod -Uri 'https://cdn.desktop.baimiaoapp.com/updater/update.json'

# Version
$Task.CurrentState.Version = [regex]::Match($Object.name, 'v(.+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object.platforms.'windows-x86_64'.url
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = "白描桌面版_$($Task.CurrentState.Version)_x64_zh-CN.msi"
    }
  )
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.pub_date.ToUniversalTime()

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.notes | Format-Text
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
