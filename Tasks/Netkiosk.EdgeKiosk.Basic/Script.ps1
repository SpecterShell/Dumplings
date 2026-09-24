$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x86'
  InstallerType       = 'zip'
  NestedInstallerType = 'inno'
  InstallerUrl        = 'https://netkiosk.co.uk/wp-content/uploads/2026/08/NetkioskEdgeKioskBasicSetup.zip'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Auto'
    ReadVersion = {
      param($Path)
      $ExtractedPath = Expand-TempArchive -Path $Path -Name '*.exe' -CollisionAction Error
      try {
        $InnerInstaller = Get-ChildItem -LiteralPath $ExtractedPath -Filter '*.exe' | Select-Object -First 1
        (Get-InnoInfo -Path $InnerInstaller.FullName).AppVersion
      } finally {
        Remove-Item -LiteralPath $ExtractedPath -Recurse -Force
      }
    }
  })
$this.CompleteInstallerUpdates($Result)
