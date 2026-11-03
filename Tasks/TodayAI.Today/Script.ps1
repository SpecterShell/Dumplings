# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https://releases.today.ai/apps/today/desktop/windows/latest/today-windows-x64.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https://releases.today.ai/apps/today/desktop/windows/latest/today-windows-arm64.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'Header'
  HeaderName  = 'x-amz-meta-sha256'
  ReadVersion = { param($Path) Read-ProductVersionFromNSIS -Path $Path }
})
$this.CompleteInstallerUpdates($Result)
