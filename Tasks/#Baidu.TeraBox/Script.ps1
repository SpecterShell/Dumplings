$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['TeraBox'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['TeraBox'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-WebRequest -Uri 'https://www.terabox.com/autoupdate' -Headers @{
  Pragma = 'ver=1.20.0.6;channel=00000000000000000000000000000000;clienttype=8;update_type=manual;xp_sp3=1;win7_later=1'
} -SkipHeaderValidation | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.AutoUpdate.Module.version

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesEN = ('"' + ($Object1.AutoUpdate.Module.FullPackage.hint_en ?? $Object1.AutoUpdate.Module.Upgrade.hint_en) + '"') | ConvertFrom-Json | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotesEN = $ReleaseNotesEN
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
