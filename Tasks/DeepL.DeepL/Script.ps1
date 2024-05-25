$Object1 = (Invoke-RestMethod -Uri 'https://appdownload.deepl.com/windows/0install/deepl.xml').SelectNodes('//*[name()="implementation" and @stability="stable"]') | Sort-Object -Property { $_.version -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = 'https://appdownload.deepl.com/windows/0install/DeepLSetup.exe'
}

# The installer could be updated independently from the update feed
$Object2 = Invoke-WebRequest -Uri $InstallerUrl -Method Head -Headers @{'If-Modified-Since' = $this.LastState['LastModified'] } -SkipHttpErrorCheck
if ($Object2.StatusCode -ne 304) {
  $this.Status.Add('Changed')
  $this.Config.IgnorePRCheck = $true
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
