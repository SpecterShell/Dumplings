$Object1 = (Invoke-RestMethod -Uri 'https://cdn.freedom.to/installers/updates/win/update.txt' | ConvertFrom-Ini).GetEnumerator().Where({ $_.Name.StartsWith('Freedom ') }, 'First')[0].Value

# Version
$this.CurrentState.Version = $Object1.Version -replace '(?:\.0)+$'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.URL
  ProductCode  = "Freedom $($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.ReleaseDate, 'dd/MM/yyyy', $null).Tostring('yyyy-MM-dd')

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
