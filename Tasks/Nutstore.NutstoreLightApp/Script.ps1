$Response = Invoke-RestMethod -Uri 'https://www.jianguoyun.com/static/exe/latestVersion'
# x86
$Object1 = $Response | Where-Object -Property 'OS' -EQ -Value 'windows-lightapp-electron-x86'
# x64
$Object2 = $Response | Where-Object -Property 'OS' -EQ -Value 'windows-lightapp-electron-x64'
# arm64
$Object3 = $Response | Where-Object -Property 'OS' -EQ -Value 'windows-lightapp-electron-arm64'

# Version
$Task.CurrentState.Version = $Object2.exVer

if ((@($Object1, $Object2, $Object3) | Sort-Object -Property 'exVer' -Unique).Length -gt 1) {
  Write-Host -Object "Task $($Task.Name): The versions are different between the architectures" -ForegroundColor Yellow
  $Task.Config.Notes = '各个架构的版本号不相同'
}

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.exUrl
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.exUrl
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object3.exUrl
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and (@($Object1, $Object2, $Object3) | Sort-Object -Property 'exVer' -Unique).Length -eq 1 }) {
    New-Manifest
  }
}
