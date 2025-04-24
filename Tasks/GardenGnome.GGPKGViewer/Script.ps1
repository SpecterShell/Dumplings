$Prefix = 'https://ggnome.com/ggpkgviewer/'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'user'
  InstallerUrl = $InstallerUrlUser = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('_na') } catch {} }, 'First')[0].href
}
$VersionUser = [regex]::Match($InstallerUrlUser, '(\d+(_\d+)+)').Groups[1].Value.Replace('_', '.')

$this.CurrentState.Installer += [ordered]@{
  Scope        = 'machine'
  InstallerUrl = $InstallerUrlMachine = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('_na') } catch {} }, 'First')[0].href
}
$VersionMachine = [regex]::Match($InstallerUrlMachine, '(\d+(_\d+)+)').Groups[1].Value.Replace('_', '.')

if ($VersionUser -ne $VersionMachine) {
  $this.Log("User version: ${VersionUser}")
  $this.Log("Machine version: ${VersionMachine}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionMachine

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
