$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['Dashboard'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['Dashboard'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://wddashboarddownloads.wdc.com/wdDashboard/config/lista_updater.xml'

# Version
$this.CurrentState.Version = $Object1.lista.Application_Installer.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.lista.Application_Installer.create_date, 'MM/dd/yyyy', $null)

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime = $this.CurrentState.ReleaseTime
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }

    $this.Print()
    $this.Write()
  }
  { $_ -match 'Changed' -and $_ -notmatch 'Updated|Rollbacked' } {
    $this.Message()
  }
  { $_ -match 'Updated|Rollbacked' -and -not $OldReleases.Contains($this.CurrentState.Version) } {
    $this.Message()
  }
}
