$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.realvnc.com/en/connect/download/vnc/' | Join-String -Separator "`n" | ConvertFrom-Html

$InstallerUrl = $Object1.SelectSingleNode('//option[contains(@data-file, "-msi.zip")]').Attributes['data-file'].Value

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "VNC-Server-$($this.CurrentState.Version)-Windows-en-32bit.msi"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "VNC-Server-$($this.CurrentState.Version)-Windows-en-64bit.msi"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
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
