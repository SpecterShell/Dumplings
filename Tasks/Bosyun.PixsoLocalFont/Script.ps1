$Object1 = Invoke-WebRequest -Uri 'https://pixso.cn/download/'
$Object2 = $Object1 | ConvertFrom-Html

$Prefix = [regex]::Match($Object1.Content, 'window\.location\.href\s*=\s*"([^"]+)"\s*\+\s*_href').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object2.SelectSingleNode('//*[contains(@class, "apps-item") and contains(., "本地字体助手")]//*[contains(@data-href, ".exe")]').Attributes['data-href'].Value
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
