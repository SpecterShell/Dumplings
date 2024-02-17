$Object1 = Invoke-WebRequest -Uri 'https://www.antutu.com/' | ConvertFrom-Html

$Node = $Object1.SelectNodes('//*[@class="download" and contains(./div/h4/text()[1], "安兔兔评测") and contains(./div/h4/span, "Win")]')

# Version
$this.CurrentState.Version = [regex]::Match(
  $Node.SelectSingleNode('./div/p/text()').InnerText,
  'v([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $Node.SelectSingleNode('./div/a').Attributes['href'].Value
}

# ReleaseTime
$this.CurrentState.ReleaseTime = ($Node.SelectSingleNode('./div/p/span').InnerText | ConvertTo-HtmlDecodedText).Trim() | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
