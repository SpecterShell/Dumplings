$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['5EClient'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['5EClient'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://api-client-arena.5eplay.com/api/home'

# Version
$this.CurrentState.Version = $Object1.data.login_version_note.version

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesCN = $Object1.data.login_version_note.content.ForEach({ $_.category_name + "`n" + ($_.list.ForEach({ $_.title + "`n" + $_.content }) -join "`n") }) -join "`n`n" | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotesCN = $ReleaseNotesCN
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
