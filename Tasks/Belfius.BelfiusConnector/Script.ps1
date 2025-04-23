$Object1 = Invoke-RestMethod -Uri 'https://belfiusweb.belfius.be/F2CRenderingBelfiusWeb/GEPAResource/technology=ng1/gef0.gef1.gegn.LogonInput.diamlxscreen.json?resourceType=appl&locale=en_GB'
$Object2 = $Object1.WCMContentKeys.Where({ $_.key -eq 'screens/gef0.gef1.gegn/LogonSharedPCBRCB/T1TConnectorInstallWIN' }, 'First')[0].value | ConvertTo-HtmlDecodedText | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri 'https://belfiusweb.belfius.be/' $Object2.Where({ try { $_.href.Contains('-x86.msi') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://belfiusweb.belfius.be/' $Object2.Where({ try { $_.href.Contains('-x64.msi') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+[a-zA-Z])').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
