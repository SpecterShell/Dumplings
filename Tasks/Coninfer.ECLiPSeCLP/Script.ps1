$Prefix = 'https://eclipseclp.org/Distribution/Builds/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}?C=N;O=D;V=1;F=0;P=*_*" | ConvertFrom-Html

$Version = $Object1.SelectSingleNode('/html/body/ul/li[2]/a').InnerText.Trim() -replace '/$'

# Version
$this.CurrentState.Version = $Version -replace '_', ' #'
$MainVersion = $Version.Split('_')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}${Version}/x86_64_nt/ECLiPSe_${Version}_x86_64_nt.exe"
  ProductCode  = "ECLiPSe ${MainVersion} (64 bit)"
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
    if ($MainVersion -ne ($this.Config.WinGetIdentifier.Split('.')[-2..-1] -join '.')) {
      $this.Config.WinGetNewPackageIdentifier = "Coninfer.ECLiPSeCLP.${MainVersion}"
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'PackageName'
        Value  = { $_ -replace '(\d+(?:\.\d+)+)', $MainVersion }
      }
    }
    $this.Submit()
  }
}
