# x86
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = Get-RedirectedUrl1st -Uri 'https://bff-pc.qishui.com/light/invoke/download?os=win32&arch=ia32'
}
$VersionX86 = [regex]::Match($InstallerUrlX86, '/(\d+\.\d+\.\d+)/').Groups[1].Value

# x64
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = Get-RedirectedUrl1st -Uri 'https://bff-pc.qishui.com/light/invoke/download?os=win32&arch=x64'
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '/(\d+\.\d+\.\d+)/').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockSodaMusic')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("SodaMusic-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["SodaMusic-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
