$Prefix = 'https://openrainbow.com/downloads/'
# x86 user
$Object1 = Invoke-RestMethod -Uri "${Prefix}latest_desktop.yml" | ConvertFrom-Yaml
# x86 machine
$Object2 = Invoke-RestMethod -Uri "${Prefix}latest_desktop_machine.yml" | ConvertFrom-Yaml
# x64 user
$Object3 = Invoke-RestMethod -Uri "${Prefix}latest_desktop-x64.yml" | ConvertFrom-Yaml
# x64 machine
$Object4 = Invoke-RestMethod -Uri "${Prefix}latest_desktop_machine-x64.yml" | ConvertFrom-Yaml

if (@(@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.version } -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x86 user: $($Object1.version), x86 machine: $($Object2.version), x64 user: $($Object3.version), x64 machine: $($Object4.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object3.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  Scope         = 'user'
  InstallerUrl  = $Prefix + $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  Scope         = 'machine'
  InstallerUrl  = $Prefix + $Object2.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'msi'
  Scope         = 'machine'
  InstallerUrl  = $Prefix + $Object2.files[0].url.Replace('_Electron', '_Offline').Replace('.exe', '.msi')
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  Scope         = 'user'
  InstallerUrl  = $Prefix + $Object3.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  Scope         = 'machine'
  InstallerUrl  = $Prefix + $Object4.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  Scope         = 'machine'
  InstallerUrl  = $Prefix + $Object4.files[0].url.Replace('_Electron', '_Offline').Replace('.exe', '.msi')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
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
