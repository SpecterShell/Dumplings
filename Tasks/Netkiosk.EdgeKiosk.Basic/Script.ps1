$Object1 = Invoke-WebRequest -Uri 'https://netkiosk.co.uk/kiosk-software-download-netkiosk/'

$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x86'
  InstallerType       = 'zip'
  NestedInstallerType = 'inno'
  InstallerUrl        = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href -match 'EdgeKiosk' -and $_.href -match 'Basic' } catch {} }, 'First')[0].href
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
