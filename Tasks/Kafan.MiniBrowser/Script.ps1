$Object1 = Invoke-WebRequest -Uri 'https://browser.kfsafe.cn/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//p[@class="txt2"]').InnerText,
  '(\d+\.\d+\.\d+\.\d+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//a[@class="btn"]').Attributes['href'].Value.Replace('http://browser-download.kfsafe.cn/', 'https://browser.kfsafe.cn/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
