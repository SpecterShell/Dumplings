$Object1 = Invoke-WebRequest -Uri 'https://1ic.nl/download' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//span[text()="Version "]/following-sibling::text()').InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://1ic.nl' $Object1.SelectSingleNode('//a[@class="link1"]').Attributes['href'].Value | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # RealVersion
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
