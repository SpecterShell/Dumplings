$Object = Invoke-WebRequest -Uri 'https://staticcdn.duckduckgo.com/windows-desktop-browser/DuckDuckGo.appinstaller' | Read-ResponseContent | ConvertFrom-Xml

# Version
$Task.CurrentState.Version = $Object.AppInstaller.Version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.AppInstaller.MainBundle.Uri
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
