function Get-ReleaseNotes {
  $Object2 = $null
  try {
    $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://cjwdev.com/Software/AccountReset/VersionHistory.txt').RawContentStream)

    while (-not $Object2.EndOfStream) {
      $String = $Object2.ReadLine()
      if ($String -match "^Version $([regex]::Escape($this.CurrentState.Version))$") {
        break
      }
    }
    if (-not $Object2.EndOfStream) {
      $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String -notmatch '^Version \d+(\.\d+)+$') {
          $ReleaseNotesObjects.Add($String -replace '^\t')
        } else {
          break
        }
      }
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesObjects | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  } finally {
    if ($Object2) { $Object2.Dispose() }
  }
}

$Prefix = 'https://cjwdev.com/Software/AccountReset/Download.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href
}

$Result = $this.CheckInstallerUpdates(@{
  Validator = 'ETag'
  Installers = @(
    @{ InstallerIndex = 0; LegacyState = @{ ValidatorField = 'ETag'; InstallerIndex = 0 } }
    @{ InstallerIndex = 1; LegacyState = @{ ValidatorField = 'ETag'; InstallerIndex = 1 } }
  )
  ReadVersion = {
    param($Path, $Installer)
    $Extracted = Expand-TempArchive -Path $Path -RelativeFilePath 'AccountResetInstaller.exe' -CollisionAction Rename
    try {
      (Get-AdvancedInstallerMsiInfo -Path (Join-Path $Extracted 'AccountResetInstaller.exe') -Architecture $Installer.Architecture).DisplayVersion
    } finally {
      Remove-Item -LiteralPath $Extracted -Recurse -Force -ErrorAction Continue -ProgressAction SilentlyContinue
    }
  }
})
if ($Result.NeedsMetadata) { Get-ReleaseNotes }
$this.CompleteInstallerUpdates($Result)
