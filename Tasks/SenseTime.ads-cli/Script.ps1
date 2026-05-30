$Object1 = Invoke-WebRequest -Uri 'https://www.sensecore.cn/help/docs/cloud-foundation/storage/ads'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object1.Links.Where({ try { $_.href.EndsWith('.tar.gz') -and $_.href -match 'ads-cli' } catch {} }, 'First')[0].href 'ads-cli.exe'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
