$Object1 = Invoke-WebRequest -Uri 'https://us.workplace.datto.com/download' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[./div[@class="agentVersionText"] and contains(., "Windows")]')

# Version
$this.CurrentState.Version = [regex]::Match(
  ($Object2.SelectSingleNode('./div[@class="agentVersionText"]').InnerText | ConvertTo-HtmlDecodedText),
  'Version ([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = $Object2.SelectSingleNode('.//a').Attributes['href'].Value | ConvertTo-HtmlDecodedText
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = "https://us.workplace.datto.com/update/DattoWorkplace_x86_v$($this.CurrentState.Version).msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://us.workplace.datto.com/update/DattoWorkplace_x64_v$($this.CurrentState.Version).msi"
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
