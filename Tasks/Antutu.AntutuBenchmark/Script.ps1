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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = ($Node.SelectSingleNode('./div/p/span').InnerText | ConvertTo-HtmlDecodedText).Trim() | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
