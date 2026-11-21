$Object1 = Invoke-WebRequest -Uri 'https://miktex.org/download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = [uri]::new([uri]'https://miktex.org', $Object1.SelectSingleNode('//div[@id="basic"]//a[contains(@href, ".exe")]').Attributes['href'].Value).AbsoluteUri
}

# Version
$this.CurrentState.Version = [regex]::Match($Installer.InstallerUrl, 'miktex-(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.SelectSingleNode('//div[@id="basic"]//div[@class="row" and contains(./div[1], "Date")]/div[2]').InnerText, 'MM/dd/yyyy', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
