$Object1 = Invoke-WebRequest -Uri 'https://www.crestron.com/Products/Featured-Solutions/AirMedia/Airmedia-Apps' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//tr[contains(./td[1], "AirMedia Peripheral Installer")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./td[2]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Prefix = $Object2.SelectSingleNode('./td[1]//a').Attributes['href'].Value
$Object3 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object3.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('./td[3]').InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = Join-Uri $Prefix $Object3.Links.Where({ try { $_.outerHTML.Contains('Release Notes') } catch {} }, 'First')[0].href
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
