$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://boardmix.cn/download/'
  Invoke-PlaywrightJavaScript -Page $Page -Expression '() => ossMap'
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
