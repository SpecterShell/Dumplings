$InstallerUrl = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://connection.nwea.org/s/technical-resources'
  Read-PlaywrightLocator -Page $Page -Selector 'xpath=//a[contains(@href, ".exe") and contains(@href, "Setup_Lockdown_Browser")]' -Property Attribute -AttributeName href
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
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
