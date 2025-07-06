# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Global:DumplingsStorage.YenkaDownloadPage.Links.Where({ try { $_.outerHTML.Contains('et_pb_button') -and $_.href -match 'yenka_(\d+(?:_\d+){3})_(?!de|es)' } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = $Matches[1].Replace('_', '.')

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
