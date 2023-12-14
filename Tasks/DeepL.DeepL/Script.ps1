$Content = (Invoke-RestMethod -Uri 'https://appdownload.deepl.com/windows/x64/RELEASES').Split(' ')

# Version
$Task.CurrentState.Version = [regex]::Match($Content[1], 'DeepL-([\d\.]+)-full\.nupkg').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://appdownload.deepl.com/windows/full/$($Task.CurrentState.Version.Replace('.', '_'))/DeepLSetup.exe"
}

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
