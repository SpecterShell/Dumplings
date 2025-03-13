$Object1 = Invoke-WebRequest -Uri 'https://www.azul.com/products/components/icedtea-web/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('win') -and $_.href.Contains('i686') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('win') -and $_.href.Contains('x64') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($Installer.InstallerUrl, '(\d+(?:\.\d+){2,}-\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
