$Object1 = (Invoke-WebRequest -Uri 'https://download.voxbi.team/windows/updates.txt' | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Ini).GetEnumerator().Where({ $_.Name.StartsWith('Update') }, 'First')[0].Value

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $ReleaseNotesList = [ordered]@{}
      if ($Object1.Contains('Feature')) {
        $ReleaseNotesList['New Features'] = $Object1.GetEnumerator().Where({ $_.Name.StartsWith('Feature') }).ForEach({ $_.Value })
      }
      if ($Object1.Contains('Enhancement')) {
        $ReleaseNotesList['Enhancements'] = $Object1.GetEnumerator().Where({ $_.Name.StartsWith('Enhancement') }).ForEach({ $_.Value })
      }
      if ($Object1.Contains('BugFix')) {
        $ReleaseNotesList['Fixed Bugs'] = $Object1.GetEnumerator().Where({ $_.Name.StartsWith('BugFix') }).ForEach({ $_.Value })
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesList.GetEnumerator().ForEach({ "$($_.Name)`n$($_.Value | ConvertTo-UnorderedList)" }) -join "`n`n" | Format-Text
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
