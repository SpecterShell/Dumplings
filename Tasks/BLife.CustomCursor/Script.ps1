$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://custom-cursor.com/products/custom-cursor-for-windows'
  $null = Invoke-PlaywrightCloudflareChallenge -Page $Page
  Read-PlaywrightLocator -Page $Page -Selector 'a[href$=".exe"]' -Property Attribute -AttributeName href
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1
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
