$Object1 = Invoke-RestMethod -Uri 'https://app1.macrobondfinancial.com/app/UpdateChecker'
$Object2 = $Object1.Update.Product.Where({ $_.Name -eq 'MacrobondViewer.x64' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture      = 'x64'
  InstallerUrl      = $Object2.PackageUrl
  InstallerSwitches = [ordered]@{
    InstallLocation = "INSTALLDIR=`"<INSTALLPATH>`""
    Custom          = "PATCH=`"$($Object2.Patch.PatchUrl)`" MBSOURCEURL=`"$($Object2.PackageUrl | Split-Uri -Parent)`""
  }
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
