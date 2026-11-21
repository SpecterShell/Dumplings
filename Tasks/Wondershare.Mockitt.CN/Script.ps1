$Object1 = Invoke-WebRequest -Uri 'https://modao.cc/feature/downloads' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri 'https://cdn-release.modao.cc/' $Object1.SelectSingleNode('//*[contains(@class, "btn-download-pc") and contains(@data-href, ".exe") and contains(@data-href, "ia32") and not(contains(@data-href, "modao-ai"))]').Attributes['data-href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://cdn-release.modao.cc/' $Object1.SelectSingleNode('//*[contains(@class, "btn-download-pc") and contains(@data-href, ".exe") and contains(@data-href, "x64") and not(contains(@data-href, "modao-ai"))]').Attributes['data-href'].Value
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
