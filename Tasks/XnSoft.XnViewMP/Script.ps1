$Prefix = 'https://download.xnview.com/old_versions/XnView_MP/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}?C=N;O=D;V=1;F=0"

# Installer
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = "${Prefix}$($Object1.Links.Where({ try { $_.href -like 'XnView_MP-*-win-x64.exe' } catch {} }, 'First')[0].href)"
}
$VersionEXE = [regex]::Match($InstallerEXE.InstallerUrl, 'XnView_MP-(\d+(?:\.\d+)+)-win-x64\.exe').Groups[1].Value

$this.CurrentState.Installer += $InstallerZIP = [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = "${Prefix}$($Object1.Links.Where({ try { $_.href -like 'XnView_MP-*-win-x64.zip' } catch {} }, 'First')[0].href)"
}
$VersionZIP = [regex]::Match($InstallerZIP.InstallerUrl, 'XnView_MP-(\d+(?:\.\d+)+)-win-x64\.zip').Groups[1].Value


if ($VersionEXE -ne $VersionZIP) {
  $this.Log("Inconsistent versions: EXE: ${VersionEXE}, ZIP: ${VersionZIP}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionEXE

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$InstallerEXE.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerEXE.InstallerUrl
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
