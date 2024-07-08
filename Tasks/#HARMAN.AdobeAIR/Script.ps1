$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['AdobeAIR'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['AdobeAIR'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = (Invoke-RestMethod -Uri 'https://airsdk.harman.com/api/versions/release-notes').Where({ $_.latest -eq $true })[0]

# Version
$this.CurrentState.Version = $Object1.versionName

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releasedDate | ConvertFrom-UnixTimeMilliseconds

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes = $Object1.releaseNotes | ForEach-Object -Process { "$($_.title): $($_.description)" } | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime  = $this.CurrentState.ReleaseTime
      ReleaseNotes = $ReleaseNotes
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
}
