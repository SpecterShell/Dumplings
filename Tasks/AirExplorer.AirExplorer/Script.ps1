# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.airexplorer.net/downloads/AirExplorer-OnlineInstaller.exe'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Auto'
    ReadVersion = { param($Path) (Read-ProductVersionRawFromExe -Path $Path).ToString(3) }
  })
$this.CompleteInstallerUpdates($Result)
