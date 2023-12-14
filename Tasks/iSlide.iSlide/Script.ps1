# Installer
$InstallerUrl = Get-RedirectedUrl -Uri 'https://api.islide.cc/download/package/exe'
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($InstallerUrl, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
