$Prefix = 'https://cdn.kde.org/ci-builds/utilities/kate/'

$Object1 = Invoke-WebRequest -Uri $Prefix

$Prefix += ($Object1.Links.Where({ try { $_.href.StartsWith('release-') } catch {} }).href | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1) + 'windows/'

$Object2 = Invoke-WebRequest -Uri $Prefix

$InstallerName = $Object2.Links.Where({ try { $_.href.EndsWith('.appx') -and $_.href.Contains('x86_64') } catch {} }, 'First')[0].href
$VersionMatches = [regex]::Match($InstallerName, '(?<LongVersion>(?<ShortVersion>\d+(?:\.\d+)+)-\d+)')

# Version
$this.CurrentState.Version = $VersionMatches.Groups['LongVersion'].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $InstallerName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMSIX

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
