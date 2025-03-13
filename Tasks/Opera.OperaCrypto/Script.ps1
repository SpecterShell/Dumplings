$Object1 = Invoke-RestMethod -Uri 'https://autoupdate.geo.opera.com/api/verify' -Body @{
  product = 'Opera Crypto'
  version = $this.Status.Contains('New') ? '105.0.4970.29' : $this.LastState.Version
}

if ($Object1.status -eq 'current') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.current_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://get.opera.com/pub/opera_crypto/$($this.CurrentState.Version)/win/Opera_Crypto_$($this.CurrentState.Version)_Setup_x64.exe"
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
