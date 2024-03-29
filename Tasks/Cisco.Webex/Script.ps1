# x86
$Object1 = Invoke-RestMethod -Uri 'https://client-upgrade-a.wbx2.com/client-upgrade/api/v1/webexteamsdesktop/upgrade/@me?channel=gold&model=win-32&r=AC805C72-1377-4FE6-B272-1FB4417B50B7'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://client-upgrade-a.wbx2.com/client-upgrade/api/v1/webexteamsdesktop/upgrade/@me?channel=gold&model=win-64&r=AC805C72-1377-4FE6-B272-1FB4417B50B7'

$Identical = $true
if ($Object1.manifest.version -ne $Object2.manifest.version) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Object2.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.manifest.manualInstallPackageLocation
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.manifest.manualInstallPackageLocation
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  # ({ $_ -match 'Updated' -and $Identical }) {
  #   $this.Submit()
  # }
}
