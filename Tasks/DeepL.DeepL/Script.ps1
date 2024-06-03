$Object1 = (Invoke-RestMethod -Uri 'https://appdownload.deepl.com/windows/0install/deepl.xml').SelectNodes('//*[name()="implementation" and @stability="stable"]') | Sort-Object -Property { $_.version -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = 'https://appdownload.deepl.com/windows/0install/DeepLSetup.exe'
}

# The installer could be updated independently from the update feed
$Object2 = Invoke-WebRequest -Uri $InstallerUrl -Method Head -Headers @{'If-Modified-Since' = $this.LastState['LastModified'] } -SkipHttpErrorCheck
if ($Object2.StatusCode -eq 304) {
  # LastModified
  $this.CurrentState.LastModified = $this.LastState.LastModified
} else {
  if ($this.LastState.Contains('Version')) {
    $this.Status.Add('Changed')
    $this.Config.IgnorePRCheck = $true
  }
  # LastModified
  $this.CurrentState.LastModified = $Object2.Headers.'Last-Modified'[0]
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.released | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
    $this.Submit()
  }
}
