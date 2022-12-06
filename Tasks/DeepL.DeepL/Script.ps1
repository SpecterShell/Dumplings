$Content = (Invoke-RestMethod -Uri 'https://appdownload.deepl.com/windows/x64/RELEASES').Split(' ')

# Version
$Task.CurrentState.Version = [regex]::Match($Content[1], 'DeepL-([\d\.]+)-full\.nupkg').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://appdownload.deepl.com/windows/full/$($Task.CurrentState.Version.Replace('.', '_'))/DeepLSetup.exe"
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
