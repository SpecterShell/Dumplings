# x64
$InstallerUrl1 = Get-RedirectedUrl -Uri 'https://www.swi-prolog.org/download/stable/bin/swipl-latest.x64.exe'
$Version1 = [regex]::Match(
  $InstallerUrl1,
  'swipl-(\d+\.\d+\.\d+)'
).Groups[1].Value

# x86
$InstallerUrl2 = Get-RedirectedUrl -Uri 'https://www.swi-prolog.org/download/stable/bin/swipl-latest.x86.exe'
$Version2 = [regex]::Match(
  $InstallerUrl2,
  'swipl-(\d+\.\d+\.\d+)'
).Groups[1].Value

if ($Version1 -ne $Version2) {
  $Task.Logging('Distinct versions detected', 'Warning')
}

# Version
$Task.CurrentState.Version = $Version1

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl2
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl1
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
