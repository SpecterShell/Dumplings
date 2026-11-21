$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://professional.bloomberg.com/support/customer-support/software-updates/'
  Read-PlaywrightLocator -Page $Page -Selector html
} | ConvertFrom-Html

$OfficeToolsRow = $Object1.SelectSingleNode("//table[contains(@class, 'globalfeeds-downloads-table')]//tr[./td[contains(@class, 'name') and contains(., 'Bloomberg Office Tools')]]")
if (-not $OfficeToolsRow) {
  throw 'Bloomberg Office Tools entry not found on the software updates page.'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $OfficeToolsRow.SelectSingleNode('.//a[contains(@href, "software/trv/bxla") and not(contains(@href, "viper"))]').GetAttributeValue('href', '')
}

# Version (bxla filename encodes the first two version segments as one pair, e.g. bxla91_7_52 = 9.1.7.52)
$VersionMatch = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'bxla(\d)(\d)_(\d+)_(\d+)')
if ($VersionMatch.Success) {
  $this.CurrentState.Version = "$($VersionMatch.Groups[1].Value).$($VersionMatch.Groups[2].Value).$($VersionMatch.Groups[3].Value).$($VersionMatch.Groups[4].Value)"
} else {
  $this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $OfficeToolsRow.SelectSingleNode('./td[contains(@class, "date")]').InnerText.Trim(),
        'MMM d, yyyy',
        (Get-Culture -Name 'en-US')
      ).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
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
