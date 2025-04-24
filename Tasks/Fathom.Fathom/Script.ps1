$Object1 = Invoke-WebRequest -Uri 'https://fathom.video/download' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//*[@id="app"]').Attributes['data-page'].DeEntitizeValue | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.props.appDownloadUrls.exe
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
