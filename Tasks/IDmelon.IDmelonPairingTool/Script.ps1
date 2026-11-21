$Object1 = Invoke-RestMethod -Uri 'https://www.idmelon.com/downloads/pairing_tool/meta.json'
$Object2 = $Object1.apps.Where({ $_.id -eq 'pairingtool' })[0].platforms.Where({ $_.title -eq 'Windows' })[0].versions.Where({ $_.title -eq 'Stable' })[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.link
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Auto'
    ReadVersion = { param($Path) Read-FileVersionFromExe -Path $Path }
  })

if ($Result.NeedsMetadata) {
  try {
    $Object4 = $Object1.apps.Where({ $_.id -eq 'pairingtool' })[0].platforms.Where({ $_.title -eq 'Windows' })[0].changeLog.Where({ $_.version -eq ($this.CurrentState.Version.Split('.')[0..2] -join '.') })
    if ($Object4) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object4[0].date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4[0].description | Format-Text
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$this.CompleteInstallerUpdates($Result)
