$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://1ic.nl/BPMN_RPA/BPMN-RPA Studio.msi'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator = 'ETag'
  LegacyState = @{ ValidatorField = 'ETag' }
  ReadVersion = { param($Path) Read-ProductVersionFromMsi -Path $Path }
})
$this.CompleteInstallerUpdates($Result)
