$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['PowerAutomateDesktop'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['PowerAutomateDesktop'] = $OldReleases = [ordered]@{}
}

$Object1 = Get-TempFile -Uri 'https://go.microsoft.com/fwlink/?linkid=2166902'
# $Object1 = Get-TempFile -Uri 'https://go.microsoft.com/fwlink/?linkid=2200869'
$Object2 = 7z.exe e -y -so $Object1 'PADUpdate.json' | ConvertFrom-Json
Remove-Item -Path $Object1 -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

# Version
$this.CurrentState.Version = $Object2.latestVersion.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object2.latestVersion.releaseDate.ToUniversalTime()

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime = $this.CurrentState.ReleaseTime
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
