# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Global:DumplingsStorage.xploviewPrefix $Global:DumplingsStorage.xploviewDownloadPage.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href -match 'xploview-setup' -and $_.href -notmatch 'wireless|legacy' } catch {} }, 'First')[0].href | ConvertTo-HtmlDecodedText
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
