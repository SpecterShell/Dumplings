$Prefix = 'https://www.cypherix.com/cryptainer-pro-download-center.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'cryptainer(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Config.WinGetNewPackageIdentifier = $this.Config.WinGetIdentifier -replace '\d{2}$', $this.CurrentState.Version.Split('.')[0]
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'PackageName'
        Value  = { $_ -replace '\d{2}$', $this.CurrentState.Version.Split('.')[0] }
      }
      $this.CurrentState.Installer[0].ProductCode = "cryptainer$($this.CurrentState.Version.Split('.')[0])_is1"
    }
    $this.Submit()
  }
}
