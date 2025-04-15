$Object1 = Invoke-WebRequest -Uri 'https://www.luxaformanual.com/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('LuxaforApp') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockLuxafor')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("Luxafor-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["Luxafor-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
