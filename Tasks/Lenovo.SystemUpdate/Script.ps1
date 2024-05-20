$Object1 = (Invoke-WebRequest -Uri 'https://support.lenovo.com/us/en/downloads/ds012808').Content | Get-EmbeddedJson -StartsFrom 'window.customData || ' | ConvertFrom-Json
$Object2 = $Object1.driver.body.DriverDetails.Files.Where({ $_.URL.EndsWith('.exe') })[0]

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.URL
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object2.Date.Unix | ConvertFrom-UnixTimeMilliseconds

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
