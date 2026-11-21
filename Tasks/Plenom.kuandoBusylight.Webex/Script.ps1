$Object1 = $Global:DumplingsStorage.PlenomDownloadPage.SelectSingleNode('//ul[@class="live-search-list"]/li/a[contains(.,"Cisco WebEx Windows")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object1.innerText, 'Version: (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://www.plenom.com/download/208271/'
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://www.plenom.com/download/208271/'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = New-TempFile
    curl -fsSLA $DumplingsInternetExplorerUserAgent -o $InstallerFile $this.CurrentState.Installer[0].InstallerUrl | Out-Host
    $InstallerFileExtracted = New-TempFolder
    7z.exe x -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'Busylight4WebexSetup.msi' 'Busylight4WebexSetup64.msi' | Out-Host
    # x86
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'Busylight4WebexSetup.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    # x64
    $InstallerFile3 = Join-Path $InstallerFileExtracted 'Busylight4WebexSetup64.msi'
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
    $this.Submit()
  }
}
