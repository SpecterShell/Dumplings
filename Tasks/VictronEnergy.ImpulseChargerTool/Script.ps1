# InstallerUrl
$Software = $Global:DumplingsStorage.VictronEnergySoftwareCatalog.Where({ $_.title -eq 'Impulse PC software' }, 'First')[0]
$Object1 = Invoke-RestMethod -Uri "$($Global:DumplingsStorage.VictronEnergySoftwareApiPrefix)$($Software.id)/"
$Download = $Object1.sections.accordion.links.Where({ $_.label -match 'Impulse PC software' -and $_.url.EndsWith('.zip') }, 'First')[0]

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = Join-Uri $Global:DumplingsStorage.VictronEnergyWebsitePrefix $Download.url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = 'ImpulseSetup.msi'
    }
  )
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'ETag'
    LegacyState = @{ ValidatorField = 'ETag' }
    ReadVersion = {
      param($Path)
      $Extracted = Expand-TempArchive -Path $Path -RelativeFilePath 'ImpulseSetup.msi' -CollisionAction Rename
      try {
        Read-ProductVersionFromMsi -Path (Join-Path $Extracted 'ImpulseSetup.msi')
      } finally {
        Remove-Item -LiteralPath $Extracted -Recurse -Force -ErrorAction Continue -ProgressAction SilentlyContinue
      }
    }
  })
$this.CompleteInstallerUpdates($Result)
