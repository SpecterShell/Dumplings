$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://perbank.cdn-static.abchina.com/POBNew/ext/PowerExtensionABC.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator = 'ETag'
  LegacyState = @{ ValidatorField = 'ETag' }
  Method = 'GET'
  UserAgent = $WinGetUserAgent
  ReadVersion = { param($Path) Read-ProductVersionFromExe -Path $Path }
})
$this.CompleteInstallerUpdates($Result)
