$Object1 = Invoke-WebRequest -Uri 'https://8gadgetpack.net/' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//a[contains(@href, ".msi") and contains(text(), "Download")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.InnerText, 'v([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = $Object1.SelectSingleNode("//h2[text()='Version history']/following-sibling::ul[@class='tmo_ul_list'][1]/li[contains(., 'Version $($this.CurrentState.Version)')]")

      if ($Object3) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($Object3.InnerText, '(\d{4}-\d{2}-\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3.SelectNodes('./text()[1]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
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
