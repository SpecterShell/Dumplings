$Object = Invoke-RestMethod -Uri 'https://api.neatifyapp.com/auth/version/latest?appId=5&platform=0'

# Installer
$InstallerUrl = $Object.data.downloadUrl | ConvertTo-UnescapedUri
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\-\d+)').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.data.createTime | ConvertFrom-UnixTimeMilliseconds

# ReleaseNotes (zh-CN)
$ReleaseNotesObject = $Object.data.updateLog | ConvertFrom-Json
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
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesList | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
