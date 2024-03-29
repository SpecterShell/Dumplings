$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['iFlyRecSI1'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['iFlyRecSI1'] = $OldReleaseNotes = [ordered]@{}
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
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
}
