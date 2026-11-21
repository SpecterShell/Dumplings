$InstallerUrl = Join-Uri 'https://pohlcon.com/fileadmin/crossbase/SOF/PRO/' $Global:DumplingsStorage.PohlConDownloadPage.SelectSingleNode('//a[@class="figure__cover-link"][contains(@href,"SOF_PRO_FERBOX-DESIGN_")]').Attributes['href'].Value

# The wrapped executable name carries the marketing version, so read it from the archive before registering the entry.
$this.InstallerFiles[$InstallerUrl] = $ArchiveFile = Get-TempFile -Uri $InstallerUrl
$Archive = [System.IO.Compression.ZipFile]::OpenRead($ArchiveFile)
$InnerName = $Archive.Entries.Where({ $_.Name -like '*.exe' }, 'First')[0].FullName
$Archive.Dispose()

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = $InnerName
    }
  )
}

# The wrapper only exposes its product version through files.txt, and the server re-stamps bytes nightly without changing them.
$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Hash'
    LegacyState = @{ ValidatorField = 'LastModified'; InstallerIndex = 0 }
    ReadVersion = {
      param($Path)
      $Extracted = Expand-TempArchive -Path $Path -Name $InnerName
      try {
        $InnerExtracted = New-TempFolder
        try {
          & 7z.exe e -aoa -ba -bd -y "-o$InnerExtracted" (Join-Path $Extracted $InnerName) 'files.txt' | Out-Host
          if ($LASTEXITCODE -ne 0) { throw "7z failed to extract files.txt with exit code $LASTEXITCODE." }
          $Match = [regex]::Match((Join-Path $InnerExtracted 'files.txt' | Get-Item | Get-Content -Raw), '(?m)^DisplayVersion\r\n(\d+(?:\.\d+)+)')
          if (-not $Match.Success) { throw 'files.txt did not provide a DisplayVersion.' }
          $Match.Groups[1].Value
        } finally {
          Remove-Item -LiteralPath $InnerExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
        }
      } finally {
        Remove-Item -LiteralPath $Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
      }
    }
  })
$this.CompleteInstallerUpdates($Result)
