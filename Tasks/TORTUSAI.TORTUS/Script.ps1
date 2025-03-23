$Object1 = Invoke-WebRequest -Uri 'https://tortus.ai/download/'

# Installer
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}
$VersionEXE = [regex]::Match($InstallerEXE.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerWiX = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
}
$VersionWiX = [regex]::Match($InstallerWiX.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionEXE -ne $VersionWiX) {
  $this.Log("NSIS version: ${VersionEXE}")
  $this.Log("WiX version: ${VersionWiX}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionWiX

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
