$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.anydesk.com/AnyDesk.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator = 'LastModified'
  LegacyState = @{ ValidatorField = 'LastModified' }
  ReadVersion = { param($Path) Read-FileVersionFromExe -Path $Path }
})
$this.CompleteInstallerUpdates($Result)
