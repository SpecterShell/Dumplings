$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['iFlyRecSI1'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['iFlyRecSI1'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = (Invoke-RestMethod -Uri 'https://tongchuan.iflyrec.com/exhibition/v1/ClientPackage/selectLatestList').data.Where({ $_.osType -eq 1 }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.packageVersion

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate | ConvertFrom-UnixTimeMilliseconds

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime = $this.CurrentState.ReleaseTime
    }
    if ($this.Preference.Contains('EnableWrite') -and $this.Preference.EnableWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
}
