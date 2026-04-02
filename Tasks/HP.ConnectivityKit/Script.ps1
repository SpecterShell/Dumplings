$Object1 = Invoke-RestMethod -Uri 'https://updates.moravia-consulting.com/update.xml'

# x86
$Object2 = $Object1.update.site.os.Where({ $_.name -eq 'windows' }, 'First')[0].connkit
$VersionX86 = $Object2.f

# x64
$Object3 = $Object1.update.site.os.Where({ $_.name -eq 'windows64' }, 'First')[0].connkit
$VersionX64 = $Object3.f

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'burn'
  InstallerUrl  = $InstallerX86Url = 'https://' + $Object1.update.site.root.Replace('%1', $Object2.name.Replace('%1', $VersionX86))
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'burn'
  InstallerUrl  = $InstallerX64Url = 'https://' + $Object1.update.site.root.Replace('%1', $Object3.name.Replace('%1', $VersionX64))
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  NestedInstallerType  = 'wix'
  InstallerUrl         = $InstallerX86Url -replace '\.exe$', '_msi.zip'
  NestedInstallerFiles = @(
    [ordered]@{ RelativeFilePath = "$($InstallerX86Url | Split-Path -LeafBase).msi" }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'wix'
  InstallerUrl         = $InstallerX64Url -replace '\.exe$', '_msi.zip'
  NestedInstallerFiles = @(
    [ordered]@{ RelativeFilePath = "$($InstallerX64Url | Split-Path -LeafBase).msi" }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
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
