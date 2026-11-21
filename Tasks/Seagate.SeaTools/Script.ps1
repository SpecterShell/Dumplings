$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.seagate.com/content/dam/seagate/migrated-assets/www-content/support-content/downloads/seatools/_shared/downloads/SeaToolsWindowsInstaller.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'LastModified'
  ReadVersion = { param($Path) Read-ProductVersionFromInstallBuilder -Path $Path }
})
$this.CompleteInstallerUpdates($Result)
