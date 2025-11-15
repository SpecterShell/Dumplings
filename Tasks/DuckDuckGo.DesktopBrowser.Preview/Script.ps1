$Object1 = Invoke-WebRequest -Uri 'https://staticcdn.duckduckgo.com/windows-desktop-browser/DuckDuckGo%20Preview.appinstaller' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.AppInstaller.MainBundle.Uri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
