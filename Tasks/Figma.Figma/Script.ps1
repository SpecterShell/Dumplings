$Object1 = Invoke-RestMethod -Uri 'https://desktop.figma.com/win/RELEASE.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = "https://desktop.figma.com/win/build/Figma-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
  InstallerUrl  = "https://desktop.figma.com/win-arm/build/Figma-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://desktop.figma.com/win/build/Figma-$($this.CurrentState.Version).msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # ProductCode
    $Installer['ProductCode'] = "$($InstallerFile | Read-ProductCodeFromMsi).msq"

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockFigma')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("Figma-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["Figma-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
