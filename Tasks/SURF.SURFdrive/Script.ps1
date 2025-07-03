$Object1 = Invoke-RestMethod -Uri 'https://surfdrive.surf.nl/client-updater/' -Body @{
  platform  = 'win32'
  buildArch = 'x86_64'
  oem       = 'surfdrive'
  version   = $this.Status.Contains('New') ? '5.2.2.15536' : $this.LastState.Version
}

if ([string]::IsNullOrWhiteSpace($Object1.owncloudclient.version)) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.owncloudclient.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.owncloudclient.downloadurl
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
