$InstallerUrl = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://market.m.taobao.com/app/im/ww-home/index.html'
  $null = Wait-PlaywrightTask -Task ($Page.Locator('xpath=//span[@class="newVersion"]').First.HoverAsync())
  Read-PlaywrightLocator -Page $Page -Selector "xpath=//a[@class='windowVersions']" -Property Attribute -AttributeName href -State Visible
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '\((\d+\.\d+\.\d+[A-Za-z]*)\)').Groups[1].Value

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
