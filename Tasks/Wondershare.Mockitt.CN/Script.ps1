$Object1 = Invoke-WebRequest -Uri 'https://modao.cc/feature/downloads.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/main/section[2]/div/p').InnerText,
  'v([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri 'https://cdn-release.modao.cc/' $Object1.SelectSingleNode('//*[contains(@class, "btn-download-pc") and contains(@data-href, ".exe") and contains(@data-href, "ia32")]').Attributes['data-href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://cdn-release.modao.cc/' $Object1.SelectSingleNode('//*[contains(@class, "btn-download-pc") and contains(@data-href, ".exe") and contains(@data-href, "x64")]').Attributes['data-href'].Value
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
