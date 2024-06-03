$Object1 = Invoke-RestMethod -Uri 'https://api.neatifyapp.com/auth/version/latest?appId=5&platform=0'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.data.downloadUrl | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\-\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.createTime | ConvertFrom-UnixTimeMilliseconds

      $ReleaseNotesObject = $Object1.data.updateLog | ConvertFrom-Json -AsHashtable
      $ReleaseNotesList = @()
      if ($ReleaseNotesObject.Contains('added')) {
        $ReleaseNotesList += $ReleaseNotesObject.added -creplace '^', '[+ADDED] '
      }
      if ($ReleaseNotesObject.Contains('changed')) {
        $ReleaseNotesList += $ReleaseNotesObject.changed -creplace '^', '[*CHANGED] '
      }
      if ($ReleaseNotesObject.Contains('fixed')) {
        $ReleaseNotesList += $ReleaseNotesObject.fixed -creplace '^', '[-FIXED] '
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesList | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
