$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.benq.com/en-us/business/support/products/ifp/instashare-2/download.html' -WaitUntil Load
  $null = Wait-PlaywrightTask -Task $Page.WaitForLoadStateAsync('NetworkIdle')
  Start-Sleep -Seconds 3
  Read-PlaywrightLocator -Page $Page -Selector 'a[href*="InstaShare 2_for Windows_1"]' -Property Attribute -AttributeName href
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1, 'InstaShare 2_for Windows_(\d+(?:\.\d+)+)_Windows_').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $Object1
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "InstaShare 2_for Windows_$($this.CurrentState.Version)/InstaShare 2-x64-$($this.CurrentState.Version).exe" })
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
