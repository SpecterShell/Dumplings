$Object1 = Invoke-WebRequest -Uri 'https://LTspice.analog.com/download/updates.txt' | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Update.ProductVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Update.URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.Update.ReleaseDate, 'dd/MM/yyyy', $null).Tostring('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $ReleaseNotesList = [ordered]@{}
      if ($Object1.Update.Contains('Feature')) {
        $ReleaseNotesList['New Features'] = $Object1.Update.GetEnumerator().Where({ $_.Name -match '^Feature\d*$' }).ForEach({ $_.Value })
      }
      if ($Object1.Update.Contains('Enhancement')) {
        $ReleaseNotesList['Enhancements'] = $Object1.Update.GetEnumerator().Where({ $_.Name -match '^Enhancement\d*$' }).ForEach({ $_.Value })
      }
      if ($Object1.Update.Contains('BugFix')) {
        $ReleaseNotesList['Fixed Bugs'] = $Object1.Update.GetEnumerator().Where({ $_.Name -match '^BugFix\d*$' }).ForEach({ $_.Value })
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesList.GetEnumerator() | ForEach-Object -Process { "$($_.Name)`n$($_.Value -join "`n" )" } | Join-String -Separator "`n`n" | Format-Text
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
