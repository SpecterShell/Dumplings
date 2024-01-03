# x64
$InstallerUrl1 = Get-RedirectedUrl -Uri 'https://www.swi-prolog.org/download/stable/bin/swipl-latest.x64.exe'
$Version1 = [regex]::Match($InstallerUrl1, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

# x86
$InstallerUrl2 = Get-RedirectedUrl -Uri 'https://www.swi-prolog.org/download/stable/bin/swipl-latest.x86.exe'
$Version2 = [regex]::Match($InstallerUrl2, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

$Identical = $true
if ($Version1 -ne $Version2) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl2
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl1
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
