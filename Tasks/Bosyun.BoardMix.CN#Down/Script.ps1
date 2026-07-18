$Object1 = Use-EdgeDriver -Headless {
  param($EdgeDriver)
  $EdgeDriver.Navigate().GoToUrl('https://boardmix.cn/download/')
  $EdgeDriver.ExecuteScript('return ossMap', $null)
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.win10 | ConvertFrom-Base64
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
