$Object = Invoke-WebRequest -Uri 'https://staticcdn.duckduckgo.com/windows-desktop-browser/DuckDuckGo.appinstaller' | Read-ResponseContent | ConvertFrom-Xml

# Version
$Task.CurrentState.Version = $Object.AppInstaller.Version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.AppInstaller.MainBundle.Uri
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
