$Object1 = Invoke-WebRequest -Uri 'https://pc.jisupdftoword.com/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="bd"]/div/div[1]/div[2]/p/text()[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="bd"]/div/div[1]/div[2]/a').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//*[@id="bd"]/div/div[1]/div[2]/p/text()[2]').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
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
