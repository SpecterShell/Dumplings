# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Global:DumplingsStorage.DMTDownloadPageUrl ($Global:DumplingsStorage.DMTDownloadPage.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('dmtdeviceenabler') } catch {} }).href | Sort-Object -Property { [RawVersion][regex]::Match($_, '(\d+(?:\.\d+)+)').Groups[1].Value } -Bottom 1)
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
