$this.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 619 -Version '4.0.0.0' -Locale 'en-US'

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl           = "https://download.wondershare.com/cbs_down/dvd-creator_$($this.CurrentState.Version)_full619.exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "Wondershare DVD Creator(Build $($this.CurrentState.Version))"
      ProductCode = 'Wondershare DVD Creator_is1'
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
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
