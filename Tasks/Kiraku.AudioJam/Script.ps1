$Object = Invoke-RestMethod -Uri 'https://api.kirakuapp.com/auth/version/latest?appId=4&platform=0'

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

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
