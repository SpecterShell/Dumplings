# Installer — the official download URL is versionless, so the version and change evidence come from the MSI bytes
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = 'https://download.matterway.io/assistant/windows/msiPerMachine/latest/matterway-assistant.msi'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator = 'ETag'
  ReadVersion = { param($Path) Read-ProductVersionFromMsi -Path $Path }
})
$this.CompleteInstallerUpdates($Result)
