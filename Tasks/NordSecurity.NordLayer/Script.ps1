$Object1 = (Invoke-WebRequest -Uri 'https://downloads.nordlayer.com/win/latest/update.xml' | Read-ResponseContent | ConvertFrom-Xml).channels.channel.Where({ $_.name -notin @('staging', 'updates', 'test') }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.releases.release.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releases.release.update.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerInfo = Get-AdvancedInstallerMsiInfo -Path $InstallerFile -Name 'NordLayerSetup.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerInfo.ProductVersion

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
