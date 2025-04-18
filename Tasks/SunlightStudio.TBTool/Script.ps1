$Object1 = Invoke-WebRequest -Uri 'https://www.tbtool.cn/' -UserAgent $DumplingsBrowserUserAgent

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, '软件版本\s*:\s*(\d+(?:\.\d+)+)').Groups[1].Value

# PackageUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'PackageUrl'
  Value = $PackageUrl = Join-Uri 'https://www.tbtool.cn/' $Object1.Links.Where({ try { $_.href.Contains('download') } catch {} }, 'First')[0].href
}

$Object2 = Invoke-WebRequest -Uri $PackageUrl

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.Content, '发布日期：(20\d{2}年\d{1,2}月\d{1,2}日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerFileExtracted = New-TempFolder
    Start-Process -FilePath $InstallerFile -ArgumentList @('/extract', $InstallerFileExtracted) -Wait
    $InstallerFile2 = Get-ChildItem -Path $InstallerFileExtracted -Include '*.msi' -Recurse | Select-Object -First 1
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
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
