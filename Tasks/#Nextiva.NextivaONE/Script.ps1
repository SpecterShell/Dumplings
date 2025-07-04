$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['Nextiva'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['Nextiva'] = $OldReleases = [ordered]@{}
}

$Prefix = 'https://storage.googleapis.com/nextivawebsites-misc/nextivaone/production/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}latest.yml" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $Object1.releaseNotes | Format-Text
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
