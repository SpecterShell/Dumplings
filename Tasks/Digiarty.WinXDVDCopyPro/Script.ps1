$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.winxdvd.com/download/winx-dvd-copy-pro.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'LastModified'
  ReadVersion = { param($Path) (Read-FileVersionFromExe -Path $Path).ToString() -replace '(\.0)+$' }
})
$this.CompleteInstallerUpdates($Result)
