$Prefix = 'https://cdn.adinstruments.com/'

# en
$Object1 = $Global:DumplingsStorage.ADInstrumentsApps.Where({ $_.ID -eq 'LabChart' -and $_.LanguageID -eq '5129' }, 'First')[0]
# ja
$Object2 = $Global:DumplingsStorage.ADInstrumentsApps.Where({ $_.ID -eq 'LabChart' -and $_.LanguageID -eq '1041' }, 'First')[0]
# zh-Hans
$Object3 = $Global:DumplingsStorage.ADInstrumentsApps.Where({ $_.ID -eq 'LabChart' -and $_.LanguageID -eq '2052' }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  InstallerUrl    = Join-Uri $Prefix $Object1.DownloadURL
}
$VersionEN = $Object1.Version

$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ja'
  InstallerUrl    = Join-Uri $Prefix $Object2.DownloadURL
}
$VersionJA = $Object2.Version

$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-Hans'
  InstallerUrl    = Join-Uri $Prefix $Object3.DownloadURL
}
$VersionSC = $Object3.Version

if (@(@($VersionEN, $VersionJA, $VersionSC) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: en-US: ${VersionEN}, ja-JP: ${VersionJA}, zh-CN: ${VersionSC}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionEN

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.'Release Date' | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      $Object4 = Invoke-WebRequest -Uri 'https://www.adinstruments.com/support/labchart' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//div[contains(./h2/text(), 'LabChart $($this.CurrentState.Version) (Win)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
