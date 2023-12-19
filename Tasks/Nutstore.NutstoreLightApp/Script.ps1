$Response = Invoke-RestMethod -Uri 'https://www.jianguoyun.com/static/exe/latestVersion'
# x86
$Object1 = $Response | Where-Object -Property 'OS' -EQ -Value 'windows-lightapp-electron-x86'
# x64
$Object2 = $Response | Where-Object -Property 'OS' -EQ -Value 'windows-lightapp-electron-x64'
# arm64
$Object3 = $Response | Where-Object -Property 'OS' -EQ -Value 'windows-lightapp-electron-arm64'

# Version
$Task.CurrentState.Version = $Object2.exVer

if ((@($Object1, $Object2, $Object3) | Sort-Object -Property 'exVer' -Unique).Count -gt 1) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Task.Config.Notes = '检测到不同的版本'
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

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and (@($Object1, $Object2, $Object3) | Sort-Object -Property 'exVer' -Unique).Count -eq 1 }) {
    $Task.Submit()
  }
}
