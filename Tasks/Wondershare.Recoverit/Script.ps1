$this.CurrentState = Invoke-WondershareJsonUpgradeApi -ProductId 4134 -Version '7.0.0' -Locale 'en-US'

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = "https://download.wondershare.com/cbs_down/recoverit_64bit_$($this.CurrentState.Version)_full4134.exe"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
