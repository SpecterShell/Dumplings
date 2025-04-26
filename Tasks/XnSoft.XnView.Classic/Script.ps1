$Prefix = 'https://download.xnview.com/old_versions/XnView_Classic/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}?C=N;O=D;V=1;P=XnView-*-win-full.exe;F=0"

$InstallerName = $Object1.Links[1].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '-([\d\.]+)[-\.]').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "${Prefix}${InstallerName}"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
