$this.CurrentState = Invoke-WondershareJsonUpgradeApi -ProductId 846 -Version '10.0.0.0' -Locale 'en-US'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.wondershare.com/cbs_down/filmora_64bit_$($this.CurrentState.Version)_full846.exe"
  ProductCode  = "Wondershare Filmora $($this.CurrentState.Version.Split('.')[0])_is1"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName = "Wondershare Filmora $($this.CurrentState.Version.Split('.')[0])(Build $($this.CurrentState.RealVersion))"
        ProductCode = "Wondershare Filmora $($this.CurrentState.Version.Split('.')[0])_is1"
      }
    )

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
