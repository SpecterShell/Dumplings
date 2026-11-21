$Prefix = 'https://ardisk.cn/download/'
$Object1 = Invoke-WebRequest -Uri $Prefix

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
}

$Result = $this.CheckInstallerUpdates(@{
  Validator = 'ContentLength'
  LegacyState = @{ ValidatorField = 'ContentLength' }
  ReadVersion = { param($Path) Read-ProductVersionFromExe -Path $Path }
})
$this.CompleteInstallerUpdates($Result)
