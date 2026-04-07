$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://custom-cursor.com/products/custom-cursor-for-windows' | Join-String -Separator "`n" | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
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
