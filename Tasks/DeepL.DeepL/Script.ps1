$Object1 = (Invoke-RestMethod -Uri 'https://appdownload.deepl.com/windows/0install/deepl.xml').SelectNodes('//*[name()="implementation" and @stability="stable"]') | Sort-Object -Property { $_.version -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://appdownload.deepl.com/windows/0install/DeepLSetup.exe'
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.released | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
