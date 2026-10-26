# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = Join-Uri 'https://pohlcon.com/fileadmin/crossbase/SOF/PRO/' $Global:DumplingsStorage.PohlConDownloadPage.SelectSingleNode('//a[@class="figure__cover-link"][contains(@href,"SOF_PRO_JDSD-EXPERT")]').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = 'EXPERT_Software_JDSD.exe'
    }
  )
}

# The server re-stamps every file nightly while the bytes stay identical, so no fast validator is reliable here.
$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Hash'
    LegacyState = @{ ValidatorField = 'LastModified'; InstallerIndex = 0 }
    ReadVersion = {
      param($Path)
      $Extracted = Expand-TempArchive -Path $Path -Name 'EXPERT_Software_JDSD.exe'
      try {
        Read-ProductVersionFromExe -Path (Join-Path $Extracted 'EXPERT_Software_JDSD.exe')
      } finally {
        Remove-Item -LiteralPath $Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
      }
    }
  })
$this.CompleteInstallerUpdates($Result)
