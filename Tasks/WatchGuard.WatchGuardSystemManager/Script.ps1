$InstallerUrl = $Global:DumplingsStorage.WatchGuardDownloadPage.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('WSM') } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
  ProductCode  = "WatchGuard System Manager $($this.CurrentState.Version.Split('.')[0..1] -join '.')_is1"
}

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
