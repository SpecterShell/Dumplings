$Object1 = Invoke-RestMethod -Uri 'https://fn.kirakuapp.com/admin/version/listNew' -Method Post -Form @{
  platform = '0'
  prodNo   = '1'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.data[0].downloadUrl | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.-]+)\.exe').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.data[0].createTime | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$ReleaseNotesObject = $Object1.data[0].updateLog | ConvertFrom-Json
$ReleaseNotesList = @()
if ($ReleaseNotesObject.added) {
  $ReleaseNotesList += $ReleaseNotesObject.added -creplace '^', '[+ADDED] '
}
if ($ReleaseNotesObject.changed) {
  $ReleaseNotesList += $ReleaseNotesObject.changed -creplace '^', '[*CHANGED] '
}
if ($ReleaseNotesObject.fixed) {
  $ReleaseNotesList += $ReleaseNotesObject.fixed -creplace '^', '[-FIXED] '
}
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesList | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
