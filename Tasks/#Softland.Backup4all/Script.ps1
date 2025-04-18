$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['Backup4all'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['Backup4all'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://www.backup4all.com/updatecheck/AAAA-BBBB-CCCC-DDDD-EEEE-FFFF-B4A9-3333'

# Version
$this.CurrentState.Version = "$($Object1.BACKUP4ALL.BUILDS.BUILD[0].MAJORVER).$($Object1.BACKUP4ALL.BUILDS.BUILD[0].MINORVER).$($Object1.BACKUP4ALL.BUILDS.BUILD[0].BUILD)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = $Object1.BACKUP4ALL.DOWNLOAD.LINK
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.BACKUP4ALL.BUILDS.BUILD[0].DATE, 'dd-MM-yyyy', $null) | Get-Date -Format 'yyyy-MM-dd'

    $ReleaseNotes = @()
    if ($Object1.BACKUP4ALL.BUILDS.BUILD[0].SelectSingleNode('UPDATES')) {
      $ReleaseNotes += $Object1.BACKUP4ALL.BUILDS.BUILD[0].UPDATES.UPDATE
    }
    if ($Object1.BACKUP4ALL.BUILDS.BUILD[0].SelectSingleNode('FIXES')) {
      $ReleaseNotes += $Object1.BACKUP4ALL.BUILDS.BUILD[0].FIXES.FIX
    }
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $ReleaseNotes | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime  = $this.CurrentState.ReleaseTime
      ReleaseNotes = $ReleaseNotes
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }
  }
  'New' {
    $this.Print()
    $this.Write()
  }
  { $_ -match 'Changed' -and $_ -notmatch 'Updated|Rollbacked' } {
    $this.Print()
    $this.Write()
    $this.Message()
  }
  'Updated' {
    $this.Print()
    $this.Write()
    if (-not $OldReleases.Contains($this.CurrentState.Version)) {
      $this.Message()
    }
  }
  { $_ -match 'Rollbacked' -and -not $OldReleases.Contains($this.CurrentState.Version) } {
    $this.Print()
    $this.Message()
  }
}
