$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://logtagrecorders.com/software/logtag-xpress/' | Join-String -Separator "`n" | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = curl -fsSLIA $DumplingsInternetExplorerUserAgent -w '%{url_effective}' $Object1.SelectSingleNode('//a[text()="Download"]').Attributes['href'].Value | Select-Object -Last 1
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'LTXpress_(\d+(r\d+)?)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # NestedInstallerFiles
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @(7z.exe l -ba -slt $InstallerFile '*.exe' | Where-Object -FilterScript { $_ -match '^Path = ' } | ForEach-Object -Process { [ordered]@{ RelativeFilePath = [regex]::Match($_, '^Path = (.+)').Groups[1].Value } } | Select-Object -First 1)
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath -Resolve
    $InstallerFile2Extracted = New-TempFolder
    Start-Process -FilePath $InstallerFile2 -ArgumentList @('/extract', $InstallerFile2Extracted) -Wait
    $InstallerFile3 = Get-ChildItem -Path $InstallerFile2Extracted -Include '*.msi' -Recurse | Select-Object -First 1
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
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
