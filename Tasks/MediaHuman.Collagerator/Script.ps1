$Object1 = Invoke-WebRequest -Uri 'https://www.mediahuman.com/collagerator/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//span[@itemprop="softwareVersion"]').InnerText

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.mediahuman.com/files/Collagerator.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.SelectSingleNode('.//span[@itemprop="datePublished"]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
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
