# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Use-PlaywrightPage -Stealth -Headless {
    param($Page)
    $null = Open-PlaywrightPage -Page $Page -Uri 'https://docs.wasabi.com/docs/how-do-i-use-wasabi-explorer-for-windows-with-wasabi'
    Read-PlaywrightLocator -Page $Page -Selector 'xpath=//a[contains(@href, ".exe") and contains(@href, "WasabiExplorerSetup")]' -Property Attribute -AttributeName href
  }
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..1] -join '.'

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
