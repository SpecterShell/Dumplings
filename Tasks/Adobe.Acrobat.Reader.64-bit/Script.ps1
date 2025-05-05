$Object1 = Invoke-RestMethod -Uri 'https://rdc.adobe.io/reader/products?lang=mui&site=otherversions&os=Windows%2011&api_key=dc-get-adobereader-cdn'
$Object2 = $Object1.products.reader.Where({ $_.displayName.Contains('64bit') }, 'First')[0]
$Object3 = Invoke-RestMethod -Uri 'https://rdc.adobe.io/reader/downloadUrl' -Body @{
  name    = $Object2.displayName
  os      = 'Windows 11'
  site    = 'enterprise'
  lang    = 'mui'
  api_key = 'dc-get-adobereader-cdn'
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.downloadURL
}

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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockAcrobatReaderX64')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("AcrobatReaderX64-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["AcrobatReaderX64-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
