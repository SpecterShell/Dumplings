function Get-ReleaseNotes {
  param([string]$InstallerFile)
  $InstallerFileExtracted = New-TempFolder
  $Object2 = $null
  $Object3 = $null
  try {
    7z.exe e -aoa -ba -bd -y -o"$InstallerFileExtracted" $InstallerFile 'ReleaseNotes.txt' | Out-Host
    $InstallerFile3 = (Get-Item -Path (Join-Path $InstallerFileExtracted 'ReleaseNotes.txt')).FullName
    $Object2 = [System.IO.File]::OpenRead($InstallerFile3)
    $Object3 = [System.IO.StreamReader]::new($Object2)

    while (-not $Object3.EndOfStream) {
      $String = $Object3.ReadLine()
      if ($String -match "Version $([regex]::Escape($this.CurrentState.Version))") {
        if ($String -match '(\d{1,2}-[a-zA-Z]+-20\d{2})') {
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
        }
        $null = $Object3.ReadLine()
        break
      }
    }
    if (-not $Object3.EndOfStream) {
      $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
      while (-not $Object3.EndOfStream) {
        $String = $Object3.ReadLine()
        if ($String -notmatch 'Version \d+(\.\d+)+') {
          $ReleaseNotesObjects.Add($String)
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
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }

  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  } finally {
    if ($Object3) { $Object3.Dispose() }
    elseif ($Object2) { $Object2.Dispose() }
    Remove-Item -LiteralPath $InstallerFileExtracted -Recurse -Force -ErrorAction Continue -ProgressAction SilentlyContinue
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.folder-size-explorer.com/download-fse.php'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator = 'Header'
  HeaderName = 'x-goog-hash'
  SelectValue = { param($Values) @($Values) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.StartsWith('md5=') } | ForEach-Object { $_.Substring(4) } }
  LegacyState = @{ ValidatorField = 'Hash' }
  ReadVersion = {
    param($Path)
    $Extracted = New-TempFolder
    try {
      7z.exe e -aoa -ba -bd -y -o"$Extracted" $Path 'FolderSizeExplorer.msi' | Out-Host
      Read-ProductVersionFromMsi -Path (Join-Path $Extracted 'FolderSizeExplorer.msi')
    } finally {
      Remove-Item -LiteralPath $Extracted -Recurse -Force -ErrorAction Continue -ProgressAction SilentlyContinue
    }
  }
})
if ($Result.NeedsMetadata -and $Result.Artifacts[0].Path) { Get-ReleaseNotes -InstallerFile $Result.Artifacts[0].Path }
$this.CompleteInstallerUpdates($Result)
