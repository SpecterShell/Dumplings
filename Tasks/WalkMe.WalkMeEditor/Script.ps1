$Object1 = Invoke-WebRequest -Uri 'https://www.walkme.com/download/'

# Installer
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'exe'
  Scope         = 'user'
  InstallerUrl  = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('PerUserInstallers') } catch {} }, 'First')[0].href
}
$VersionEXE = [regex]::Match($InstallerEXE.InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

$this.CurrentState.Installer += $InstallerWiX = [ordered]@{
  InstallerType = 'wix'
  Scope         = 'machine'
  InstallerUrl  = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('PerMachineInstallers') } catch {} }, 'First')[0].href
}
$VersionWiX = [regex]::Match($InstallerWiX.InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

if ($VersionEXE -ne $VersionWiX) {
  $this.Log("User version: ${VersionEXE}")
  $this.Log("Machine version: ${VersionWiX}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionEXE

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
