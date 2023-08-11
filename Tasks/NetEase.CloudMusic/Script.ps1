$Object1 = Invoke-RestMethod `
  -Uri 'https://interface.music.163.com/api/pc/upgrade/get' `
  -Method Post `
  -Headers @{ Cookie = 'osver=Microsoft-Windows-10; appver=0.0' } `
  -Body 'action=manual&cpuBitWidth=32&e_r=false'

# Version
$Task.CurrentState.Version = "$($Object1.data.packageVO.appver).$($Object1.data.packageVO.buildver)"

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.packageVO.downloadUrl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = '"' + $Object1.data.upgradeContent + '"' | ConvertFrom-Json | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
}
