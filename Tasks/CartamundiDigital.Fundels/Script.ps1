# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.fundels.com/download/fundels_exe'
}

$Object1 = Get-WebResponseHeader -Uri $this.CurrentState.Installer[0].InstallerUrl -Method GET -UserAgent $DumplingsBrowserUserAgent

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Headers.'Content-Disposition'[0], '(\d+(?:\.\d+)+)').Groups[1].Value

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
