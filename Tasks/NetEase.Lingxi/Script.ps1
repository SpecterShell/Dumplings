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
  Write-Host -Object "Task $($Task.Name): Distinct versions detected" -ForegroundColor Yellow
  $Task.Config.Notes = '检测到不同的版本'
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $Version1 -eq $Version2 }) {
    New-Manifest
  }
}
