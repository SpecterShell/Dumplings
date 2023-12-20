$this.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 4622 -Version '1.0.0.0' -Locale 'en-US'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://download.wondershare.com/cbs_down/filmorapro_full4622.exe'
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://download.wondershare.com/cbs_down/filmora_64bit_full4622.exe'
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
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
