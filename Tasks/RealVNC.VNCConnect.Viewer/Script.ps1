$Object1 = [regex]::Match(
  (Invoke-PlaywrightFetch -Uri 'https://www.realvnc.com/en/connect/download/viewer/' -Headless -Stealth -SolveCloudflare -WaitSelector 'xpath=//script[@class="rvnc-mass-config"]').Content,
  '(?s)<script[^>]*class="rvnc-mass-config"[^>]*>(.*?)</script>'
).Groups[1].Value | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.index.products.'realvnc-connect-viewer'.platforms.windows.latest_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = Join-Uri 'https://downloads.realvnc.com/download/file/realvnc-connect-viewer/' $Object1.index.products.'realvnc-connect-viewer'.platforms.windows.files.Where({ $_.arch -eq 'x64' -and $_.pkg -eq 'zip' }, 'First')[0].file
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "RealVNC-Connect-Viewer-$($this.CurrentState.Version)-Windows.msi"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Get-Item
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
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
