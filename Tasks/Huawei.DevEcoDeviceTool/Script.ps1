$Object1 = Invoke-WebRequest -Uri 'https://device.harmonyos.com/cn/develop/ide/' | ConvertFrom-Html

$InstallerNameNode = $Object1.SelectSingleNode('//div[contains(@class,"isdownLoad") and contains(./p/text(), "devicetool") and contains(./p/text(), "windows")]')

# Version
$this.CurrentState.Version = [regex]::Match(
  $InstallerNameNode.InnerText,
  '(\d+\.\d+\.\d+\.\d+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = [regex]::Match($InstallerNameNode.SelectSingleNode('./following-sibling::a').Attributes['onclick'].Value, "'(https?://.+?)'").Groups[1].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "devicetool-windows-tool-$($this.CurrentState.Version).exe"
    }
  )
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
