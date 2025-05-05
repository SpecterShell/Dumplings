# Version
$RawVersion = [regex]::Match(
  (Get-TempFile -Uri 'https://armmf.adobe.com/arm-manifests/win/AcrobatDCx64Manifest3.msi' | Read-MsiProperty -Query "SELECT FileSequences FROM ProductUpdatesEx WHERE ProductCode='{AC76BA86-1033-FF00-7760-BC15014EA700}'"), # DESC doesn't work here. Assume the latest version comes first.
  '(\d{10})'
).Groups[1].Value
$this.CurrentState.Version = $RawVersion.Insert(5, '.').Insert(2, '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/${RawVersion}/AcroRdrDCx64${RawVersion}_MUI.exe"
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
