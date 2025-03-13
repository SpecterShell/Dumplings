$Object1 = Invoke-RestMethod -Uri 'https://autoupdate.geo.opera.com/api/verify' -Body @{
  product = 'Opera GX'
  version = $this.Status.Contains('New') ? '109.0.5097.142' : $this.LastState.Version
}

if ($Object1.status -eq 'current') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.current_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://get.geo.opera.com/pub/opera_gx/$($this.CurrentState.Version)/win/Opera_GX_$($this.CurrentState.Version)_Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://get.geo.opera.com/pub/opera_gx/$($this.CurrentState.Version)/win/Opera_GX_$($this.CurrentState.Version)_Setup_x64.exe"
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
