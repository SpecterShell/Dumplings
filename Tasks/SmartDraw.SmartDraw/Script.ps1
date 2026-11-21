$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://waz.smartdraw.com/downloads/electron/SmartDrawSetup.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'LastModified'
  ReadVersion = { param($Path) Read-ProductVersionFromNSIS -Path $Path }
})
$this.CompleteInstallerUpdates($Result)
