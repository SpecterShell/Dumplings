$Object1 = Invoke-WebRequest -Uri 'https://staticcdn.duckduckgo.com/windows-desktop-browser/DuckDuckGo.appinstaller' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.AppInstaller.MainBundle.Uri
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
