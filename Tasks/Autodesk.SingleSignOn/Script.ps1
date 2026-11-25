$Object1 = Invoke-PlaywrightFetch -Uri 'https://www.autodesk.com/support/technical/article/caas/tsarticles/ts/A785RG35hP8oUR96WrYkn.html' -Stealth -Headless | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Where({ try { $_.href.EndsWith('.zip') -and $_.href -match 'installer' -and $_.href -match 'adsso' } catch {} }, 'First')[0].href
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'ETag'
    ReadVersion = {
      param($Path)
      $Extracted = Expand-TempArchive -Path $Path -RelativeFilePath 'AdSSO.msi' -CollisionAction Rename
      try {
        Read-ProductVersionFromMsi -Path (Join-Path $Extracted 'AdSSO.msi')
      } finally {
        Remove-Item -LiteralPath $Extracted -Recurse -Force -ErrorAction Continue -ProgressAction SilentlyContinue
      }
    }
  })

$this.CompleteInstallerUpdates($Result)
