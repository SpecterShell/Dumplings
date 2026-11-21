# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = Join-Uri 'https://pohlcon.com/fileadmin/crossbase/SOF/PRO/' $Global:DumplingsStorage.PohlConDownloadPage.SelectSingleNode('//a[@class="figure__cover-link"][contains(@href,"SOF_PRO_JDA-EXPERT")]').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = 'JDA.Setup.exe'
    }
  )
}

# The server re-stamps every file nightly while the bytes stay identical, so no fast validator is reliable here.
$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Hash'
    ReadVersion = {
      param($Path)
      $Extracted = Expand-TempArchive -Path $Path -Name 'JDA.Setup.exe'
      try {
        Read-ProductVersionFromExe -Path (Join-Path $Extracted 'JDA.Setup.exe')
      } finally {
        Remove-Item -LiteralPath $Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
      }
    }
  })
$this.CompleteInstallerUpdates($Result)
