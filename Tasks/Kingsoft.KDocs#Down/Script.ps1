$Object1 = Invoke-WebRequest -Uri 'https://www.kdocs.cn/' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [regex]::Match(
    $Object1.SelectSingleNode('//*[@data-type="windows"]').Attributes['onclick'].Value,
    '(https://[^"]+\.exe)'
  ).Groups[1].Value
}

# Version
$this.CurrentState.Version = [regex]::Match(
  $this.CurrentState.Installer[0].InstallerUrl,
  'v(\d+(?:\.\d+)+)'
).Groups[1].Value

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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockKDocs')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("KDocs-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["KDocs-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
