$Object1 = Invoke-WebRequest -Uri 'https://developer.harmonyos.com/cn/develop/deveco-studio' | ConvertFrom-Html

$InstallerNameNode = $Object1.SelectSingleNode('//div[contains(@class,"isdownLoad") and contains(./p/text(), "devecostudio") and contains(./p/text(), "windows")]')

# Version
$this.CurrentState.Version = [regex]::Match(
  $InstallerNameNode.InnerText,
  '(\d+\.\d+\.\d+\.\d+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerNameNode.SelectSingleNode('./following-sibling::a').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($InstallerNameNode.InnerText.Trim() | Split-Path -LeafBase)\deveco-studio-$($this.CurrentState.Version).exe"
    }
  )
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Object2 = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Expand-TempArchive | 
      Join-Path -ChildPath $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | 
      ForEach-Object -Process { 7z x -so $_ 'product-info.json' } | ConvertFrom-Json
    $this.CurrentState.RealVersion = $Object2.buildNumber

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
