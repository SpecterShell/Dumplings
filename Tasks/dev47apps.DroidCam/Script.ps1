$Object1 = Invoke-WebRequest -Uri 'https://www.dev47apps.com/droidcam/windows/' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [regex]::Match($Object1.SelectSingleNode('//div[@class="link"]').Attributes['onclick'].Value, "(http[^']+)").Groups[1].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

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
