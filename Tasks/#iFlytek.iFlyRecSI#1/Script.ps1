$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['iFlyRecSI1'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['iFlyRecSI1'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = (Invoke-RestMethod -Uri 'https://tongchuan.iflyrec.com/exhibition/v1/ClientPackage/selectLatestList').data.Where({ $_.osType -eq 1 })[0]

# Version
$this.CurrentState.Version = $Object1.packageVersion

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate | ConvertFrom-UnixTimeMilliseconds

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime = $this.CurrentState.ReleaseTime
    }
    if (-not $this.Preference.NoWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
}
