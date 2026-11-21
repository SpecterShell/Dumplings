$Object1 = Invoke-WebRequest -Uri 'https://pymol.org/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  ($Object1.SelectSingleNode('//*[@id="download"]').InnerText | ConvertTo-HtmlDecodedText),
  'Version (\d+(?:\.\d+)+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download"]//a[contains(@href, ".exe")]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match(
          $Object1.SelectSingleNode('//*[@id="download"]').InnerText,
          'Updated ([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{1,2})'
        ).Groups[1].Value,
        [string[]]@(
          "MMM d'st' yyyy", "MMMM d'st' yyyy",
          "MMM d'nd' yyyy", "MMMM d'nd' yyyy",
          "MMM d'rd' yyyy", "MMMM d'rd' yyyy",
          "MMM d'th' yyyy", "MMMM d'th' yyyy"
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
