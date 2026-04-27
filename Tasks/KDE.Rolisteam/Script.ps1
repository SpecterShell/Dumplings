$Prefix = 'https://cdn.kde.org/ci-builds/rolisteam/rolisteam/'

$Object1 = Invoke-WebRequest -Uri $Prefix

$Prefix += ($Object1.Links.Where({ try { $_.href.StartsWith('release-') } catch {} }).href | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1) + 'windows/'

$Object2 = Invoke-WebRequest -Uri $Prefix

$InstallerName = $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x86_64') } catch {} }, 'First')[0].href
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
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    # AppsAndFeaturesEntries > DisplayVersion
    $NSISInfo = Get-NSISInfo -Path $InstallerFile
    $this.Log("Read static $($NSISInfo.InstallerType) metadata for $($NSISInfo.ProductCode)", 'Info')
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @{
      DisplayVersion = $NSISInfo.DisplayVersion
    }
    # RealVersion
    $this.CurrentState.RealVersion = $this.CurrentState.Installer[0].AppsAndFeaturesEntries.DisplayVersion.Split('/')[-1].Trim()

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
