# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Global:DumplingsStorage.CiscoDownloadPage.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('nbr2player') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){2}-\d+)').Groups[1].Value.Replace('-', '.')

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
