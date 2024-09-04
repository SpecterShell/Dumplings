$Object1 = (Invoke-RestMethod -Uri 'http://wordpress.venturi.de/?feed=atom&s=HideVolumeOSD').Where({ $_.content.'#cdata-section'.Contains('smd_process_download') })[0]
$Object2 = $Object1.content.'#cdata-section' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri $Object2.SelectNodes('//a[@href]').Where({ $_.Attributes['href'].Value.Contains('smd_process_download') }, 'First')[0].Attributes['href'].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'HideVolumeOSD-(\d+(?:\.\d+)+)\.exe').Groups[1].Value

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
