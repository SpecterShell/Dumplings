# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://utils.distill.io/electron/download/alpha/win32/x64/latest' | ConvertTo-UnescapedUri
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'win32-x64-(.+)\.exe').Groups[1].Value

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
