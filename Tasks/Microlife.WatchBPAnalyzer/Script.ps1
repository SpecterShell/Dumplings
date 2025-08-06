$Prefix = 'https://www.microlife.com/support/software-professional-products'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.SelectSingleNode('//h2[contains(text(), "WatchBP Analyzer (2G)")]/following::a[contains(@href, ".exe")]').Attributes['href'].Value | Split-Uri -LeftPart Path | ConvertTo-UnescapedUri
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
