$Object1 = (Invoke-RestMethod -Uri 'https://asio4all.org/feed/atom/').Where({ $_.content.'#cdata-section' -match 'ASIO4ALL_\d+(?:_\d+)+\.exe' })[0]
$Object2 = $Object1.content.'#cdata-section' | ConvertFrom-Html
$InstallerName = $Object2.SelectNodes('//a[@href]') | ForEach-Object -Process { $_.Attributes['href'].Value } | Select-String -Pattern 'ASIO4ALL_\d+(?:_\d+)+\.exe' -Raw | Sort-Object -Property { $_ -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, 'ASIO4ALL_(\d+(?:_\d+)+)\.exe').Groups[1].Value.Replace('_', '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [uri]::new([uri]'https://asio4all.org', $InstallerName).AbsoluteUri
}

# PackageUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'PackageUrl'
  Value = $Object1.content.base
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
