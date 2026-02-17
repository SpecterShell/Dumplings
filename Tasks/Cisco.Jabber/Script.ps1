$Object1 = Invoke-WebRequest -Uri 'https://www.webex.com/downloads/jabber.html' -UserAgent $DumplingsBrowserUserAgent -Headers @{ Accept = 'text/html'; 'Accept-Language' = 'en-US' }

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [regex]::Match($Object1.Content, "jabberAppUrl = '([^']+)'").Groups[1].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d{14})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
