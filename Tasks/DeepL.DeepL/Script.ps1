$Object1 = (Invoke-RestMethod -Uri 'https://appdownload.deepl.com/windows/0install/deepl.xml').SelectNodes('//*[name()="implementation" and @stability="stable"]') | Sort-Object -Property { $_.version -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://appdownload.deepl.com/windows/0install/DeepLSetup.exe'
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.released | Get-Date -Format 'yyyy-MM-dd'

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
