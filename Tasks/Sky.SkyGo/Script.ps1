$Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::FromBase64String($Global:DumplingsSecret.SkyGoPfx))
$Object1 = Invoke-RestMethod -Uri $Global:DumplingsSecret.SkyGoUrl -Certificate $Certificate

# Version
$this.CurrentState.Version = $Object1.platforms.win.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.platforms.win.url
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
