$Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::FromBase64String($Global:DumplingsSecret.SkyGoPfx))
# United Kingdom
$Object1 = Invoke-RestMethod -Uri ($Global:DumplingsSecret.SkyGoUrl -f 'gb') -Certificate $Certificate
# Germany
$Object2 = Invoke-RestMethod -Uri ($Global:DumplingsSecret.SkyGoUrl -f 'de') -Certificate $Certificate
# Italy
$Object3 = Invoke-RestMethod -Uri ($Global:DumplingsSecret.SkyGoUrl -f 'it') -Certificate $Certificate
# Austria
$Object4 = Invoke-RestMethod -Uri ($Global:DumplingsSecret.SkyGoUrl -f 'at') -Certificate $Certificate

if (@(@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.platforms.win.version } -Unique).Count -gt 1) {
  $this.Log("United Kingdom version: $($Object1.platforms.win.version)")
  $this.Log("Germany version: $($Object2.platforms.win.version)")
  $this.Log("Italy version: $($Object3.platforms.win.version)")
  $this.Log("Austria version: $($Object4.platforms.win.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.platforms.win.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.platforms.win.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de-DE'
  InstallerUrl    = $Object2.platforms.win.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'it-IT'
  InstallerUrl    = $Object3.platforms.win.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de-AT'
  InstallerUrl    = $Object4.platforms.win.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
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
