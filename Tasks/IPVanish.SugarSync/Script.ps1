$Object1 = (Invoke-RestMethod -Uri 'https://updates.sugarsync.com/versioninfo').client_version_info.product.Where({ $_.name -eq 'SugarSyncCaliente_Win32' })[0]

# Version
$this.CurrentState.Version = "$($Object1.version.major).$($Object1.version.minor).$($Object1.version.revision)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.exec.path | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
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
