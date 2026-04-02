$Object1 = Invoke-WebRequest -Uri 'https://www.ptc.com/en/products/creo/creo-view/extension-express-download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.SelectSingleNode('//primary-to-action[@text="Download"]').Attributes['url'].Value | Split-Uri -LeftPart Path
}

$Object2 = [System.Net.Http.Headers.ContentDispositionHeaderValue](Invoke-WebRequest -Uri $InstallerUrl -Method Head).Headers.'Content-Disposition'[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object2.FileName, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\') })
    $ZipFile.Dispose()
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
    $InstallerFile2Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFile2Extracted}" $InstallerFile2 'pvexpress\CreoView_Express_64.msi' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile2Extracted 'CreoView_Express_64.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )
    Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
