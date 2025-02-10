$Object1 = Invoke-WebRequest -Uri 'https://www.sdrplay.com/sdrconnect/'
$Object2 = $Object1 | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Latest version: (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://www.sdrplay.com/' ([regex]::Match(($Object2.SelectSingleNode('//div[contains(@data-popmake, "sdrconnect-windows-x64")]//iframe').Attributes['src'].Value | ConvertTo-HtmlDecodedText), 'dlf=([^&]+)').Groups[1].Value)
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Object1.Content, '(\d{1,2}(?:st|nd|rd|th)\W+[A-Za-z]+\W+20\d{2})').Groups[1].Value,
        [string[]]@(
          "d'st' MMM yyyy", "d'st' MMMM yyyy",
          "d'nd' MMM yyyy", "d'nd' MMMM yyyy",
          "d'rd' MMM yyyy", "d'rd' MMMM yyyy",
          "d'th' MMM yyyy", "d'th' MMMM yyyy"
        ),
        (Get-Culture -Name 'en-US'),
        [System.Globalization.DateTimeStyles]::None
      ).ToString('yyyy-MM-dd')
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
