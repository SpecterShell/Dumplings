$Object1 = Invoke-WebRequest -Uri 'https://cara.gointegrator.com/downloads/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

$Object2 = [System.Net.Http.Headers.ContentDispositionHeaderValue](Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head).Headers.'Content-Disposition'[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object2.FileName, '(\d+(?:\.\d+)+)').Groups[1].Value

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
