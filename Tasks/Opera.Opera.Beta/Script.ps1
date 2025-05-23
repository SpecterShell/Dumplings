$Object1 = Invoke-RestMethod -Uri 'https://autoupdate.geo.opera.com/api/verify' -Body @{
  product = 'Opera beta'
  version = $this.Status.Contains('New') ? '111.0.5168.61' : $this.LastState.Version
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
  InstallerUrl = "https://get.geo.opera.com/pub/opera-beta/$($this.CurrentState.Version)/win/Opera_beta_$($this.CurrentState.Version)_Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://get.geo.opera.com/pub/opera-beta/$($this.CurrentState.Version)/win/Opera_beta_$($this.CurrentState.Version)_Setup_x64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://get.geo.opera.com/pub/opera-beta/$($this.CurrentState.Version)/win/Opera_beta_$($this.CurrentState.Version)_Setup_arm64.exe"
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
