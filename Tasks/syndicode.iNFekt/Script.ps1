$Object1 = [regex]::Match((Invoke-RestMethod -Uri 'https://infekt.ws/prog/CurrentVersion.txt'), '(?s)\{\{\{(.+)\}\}\}').Groups[1].Value | ConvertFrom-Ini

# Version
$Task.CurrentState.Version = $Object1._.'latest[stable].1'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1._.'autoupdate_download[stable].1/087'
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://infekt.ws/' | ConvertFrom-Html

    # ReleaseTime
    $Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
      [regex]::Match(
        $Object2.SelectSingleNode('/html/body/div/header/p[2]/text()[2]').InnerText,
        '\((.+)\)'
      ).Groups[1].Value,
      # "[string[]]" is needed here to convert "array" object to string array
      [string[]]@(
        "MMM d'st' yyyy", "MMMM d'st' yyyy",
        "MMM d'nd' yyyy", "MMMM d'nd' yyyy",
        "MMM d'rd' yyyy", "MMMM d'rd' yyyy",
        "MMM d'th' yyyy", "MMMM d'th' yyyy"
      ),
      (Get-Culture -Name 'en-US'),
      [System.Globalization.DateTimeStyles]::None
    ).ToString('yyyy-MM-dd')

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
