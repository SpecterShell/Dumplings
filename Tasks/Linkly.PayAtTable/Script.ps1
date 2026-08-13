# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = $Global:DumplingsStorage.LinklySoftwarePage.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href -match 'Setup' -and $_.href -match 'Linkly%20Pay%20at%20Table' } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
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
