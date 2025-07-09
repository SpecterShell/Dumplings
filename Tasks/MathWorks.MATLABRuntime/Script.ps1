$Object1 = Invoke-WebRequest -Uri 'https://www.mathworks.com/products/compiler/matlab-runtime.html' -Headers @{
  Accept            = 'text/html'
  'Accept-Encoding' = 'gzip, deflate'
  Connection        = 'close'
} -UserAgent $DumplingsBrowserUserAgent | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//tr[contains(./td[2]//@href, ".zip")]')

# Version
$VersionMatches = [regex]::Matches($Object2.SelectSingleNode('./td[1]').InnerText, '(R20\d{2}[a-zA-Z]) \((\d+(?:\.\d+)+)\)')
$this.CurrentState.Version = $VersionMatches.Groups[2].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('./td[2]//a[contains(@href, ".zip")]').Attributes['href'].Value
  ProductCode  = "MATLAB Runtime $($VersionMatches.Groups[1].Value)"
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
