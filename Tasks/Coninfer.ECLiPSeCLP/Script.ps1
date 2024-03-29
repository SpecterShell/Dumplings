$Prefix = 'https://eclipseclp.org/Distribution/Builds/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}?C=N;O=D;V=1;F=0;P=*_*" | ConvertFrom-Html

$Version = $Object1.SelectSingleNode('/html/body/ul/li[2]/a').InnerText.Trim() -replace '/$'

# Version
$this.CurrentState.Version = $Version -replace '_', ' #'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}${Version}/x86_64_nt/ECLiPSe_${Version}_x86_64_nt.exe"
  ProductCode  = "ECLiPSe $($Version.Split('_')[0]) (64 bit)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
}
