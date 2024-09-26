$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['5EClient'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['5EClient'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://api-client-arena.5eplay.com/api/home'

if ($null -eq $Object1.data.login_version_note) {
  $this.Log('The API returned an invalid response', 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.login_version_note.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCN = $Object1.data.login_version_note.content.ForEach({ $_.category_name + "`n" + ($_.list.ForEach({ $_.title + "`n" + $_.content }) -join "`n") }) -join "`n`n" | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotesCN = $ReleaseNotesCN
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
