$Object1 = $Global:DumplingsStorage.PlenomDownloadPage.SelectSingleNode('//ul[@class="live-search-list"]/li/a[contains(.,"kuando In-A-Call") and not(contains(.,"MacOS"))]')

# Version
$this.CurrentState.Version = [regex]::Match($Object1.innerText, 'Version: (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
# $this.CurrentState.Installer += $InstallerX86 = [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = ''
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    # $InstallerFileExtracted = New-TempFolder
    # # x86
    # $InstallerX86['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.msi') -and $_.FullName -notmatch '64bit' }, 'First')[0].FullName.Replace('/', '\') })
    # 7z.exe x -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $InstallerX86.NestedInstallerFiles[0].RelativeFilePath | Out-Host
    # $InstallerFile2 = Join-Path $InstallerFileExtracted $InstallerX86.NestedInstallerFiles[0].RelativeFilePath
    # # RealVersion
    # $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    # # ProductCode
    # $InstallerX86['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # # AppsAndFeaturesEntries
    # $InstallerX86['AppsAndFeaturesEntries'] = @(
    #   [ordered]@{
    #     UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
    #     InstallerType = 'wix'
    #   }
    # )
    # $ZipFile.Dispose()
    # Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.innerText, 'Date: (\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd' -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Log('This package requires manual submission. Get the installer from the website.', 'Warning')
  }
}
