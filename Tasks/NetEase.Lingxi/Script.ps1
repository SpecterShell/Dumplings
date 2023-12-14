# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl1 = Get-RedirectedUrl -Uri 'https://sirius-release.lx.netease.com/api/pub/client/update/download-win32'
}
$Version1 = [regex]::Matches($InstallerUrl1, '([\d\.]+)\.exe').Groups[-1].Value

$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl2 = Get-RedirectedUrl -Uri 'https://sirius-release.lx.netease.com/api/pub/client/update/download-windows'
}
$Version2 = [regex]::Matches($InstallerUrl2, '([\d\.]+)\.exe').Groups[-1].Value

# Version
$Task.CurrentState.Version = $Version2

if ($Version1 -ne $Version2) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Task.Config.Notes = '检测到不同的版本'
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and $Version1 -eq $Version2 }) {
    $Task.Submit()
  }
}
