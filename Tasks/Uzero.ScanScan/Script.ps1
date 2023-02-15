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
