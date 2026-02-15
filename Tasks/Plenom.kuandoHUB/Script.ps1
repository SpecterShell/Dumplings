$Object1 = $Global:DumplingsStorage.PlenomDownloadPage.SelectSingleNode('//ul[@class="live-search-list"]/li/a[contains(.,"kuandoHUB Windows")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object1.innerText, 'Version: (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
# $this.CurrentState.Installer += $InstallerX86 = [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = ''
# }
# $this.CurrentState.Installer += $InstallerX64 = [ordered]@{
#   Architecture = 'x64'
#   InstallerUrl = ''
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # $InstallerFileExtracted = New-TempFolder
    # 7z.exe x -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'kuandoHUBSetup.msi' 'kuandoHUBSetup_64bit.msi' | Out-Host
    # # x86
    # $InstallerFile2 = Join-Path $InstallerFileExtracted 'kuandoHUBSetup.msi'
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
    # # x64
    # $InstallerFile3 = Join-Path $InstallerFileExtracted 'kuandoHUBSetup_64bit.msi'
    # # ProductCode
    # $InstallerX64['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
    # # AppsAndFeaturesEntries
    # $InstallerX64['AppsAndFeaturesEntries'] = @(
    #   [ordered]@{
    #     UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
    #     InstallerType = 'wix'
    #   }
    # )
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
