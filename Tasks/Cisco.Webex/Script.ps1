# x64
$Object1 = Invoke-RestMethod -Uri 'https://client-upgrade-a.wbx2.com/client-upgrade/api/v1/webexteamsdesktop/upgrade/@me?channel=gold&model=win-64&r=AC805C72-1377-4FE6-B272-1FB4417B50B7'

# Version
$this.CurrentState.Version = $Object1.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.manifest.manualInstallPackageLocation
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
