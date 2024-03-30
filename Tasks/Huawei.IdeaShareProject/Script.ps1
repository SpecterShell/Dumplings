$Object1 = Invoke-WebRequest -Uri 'https://www.huaweicloud.com/product/ideahub/ideashare.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//div[@class="header_ops"]//div[@class="header_txt4"]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [regex]::Match(
    $Object1.SelectSingleNode('//div[@class="header_ops"]').Attributes['onclick'].Value,
    "window\.open\('(.+?)'\)"
  ).Groups[1].Value
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
