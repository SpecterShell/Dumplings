$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['novaPDF'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['novaPDF'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://www.novapdf.com/update-check.html?key=AAAA-BBBB-CCCC-DDDD-EEEE-FFFF-BD11-A111'

# Version
$this.CurrentState.Version = "$($Object1.NOVAPDF.BUILDS.BUILD[0].MAJORVER).$($Object1.NOVAPDF.BUILDS.BUILD[0].MINORVER).$($Object1.NOVAPDF.BUILDS.BUILD[0].BUILD)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.NOVAPDF.DOWNLOAD.LINK
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.NOVAPDF.BUILDS.BUILD[0].DATE, 'dd-MM-yyyy', $null) | Get-Date -Format 'yyyy-MM-dd'

    $ReleaseNotes = @()
    if ($Object1.NOVAPDF.BUILDS.BUILD[0].SelectSingleNode('UPDATES')) {
      $ReleaseNotes += $Object1.NOVAPDF.BUILDS.BUILD[0].UPDATES.UPDATE
    }
    if ($Object1.NOVAPDF.BUILDS.BUILD[0].SelectSingleNode('FIXES')) {
      $ReleaseNotes += $Object1.NOVAPDF.BUILDS.BUILD[0].FIXES.FIX
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
