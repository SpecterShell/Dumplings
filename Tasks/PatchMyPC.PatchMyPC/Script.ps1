$Object1 = (Invoke-WebRequest -Uri 'https://homeupdater.patchmypc.com/public/PatchMyPC_HomeUpdater_Production_Updates.txt' | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Ini).GetEnumerator().Where({ $_.Name.StartsWith('PROD_') }, 'First')[0].Value

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
      $ReleaseNotes = [System.Text.StringBuilder]::new()
      if ($Object1.Contains('Description')) { $ReleaseNotes = $ReleaseNotes.AppendLine($Object1.Description).AppendLine() }
      if ($Object1.Contains('Feature')) { $ReleaseNotes = $ReleaseNotes.AppendLine('New Features').AppendLine(($Object1.GetEnumerator().Where({ $_.Name -match '^Feature\d*$' }).Value | ConvertTo-UnorderedList)).AppendLine() }
      if ($Object1.Contains('Enhancement')) { $ReleaseNotes = $ReleaseNotes.AppendLine('Enhancements').AppendLine(($Object1.GetEnumerator().Where({ $_.Name -match '^Enhancement\d*$' }).Value | ConvertTo-UnorderedList)).AppendLine() }
      if ($Object1.Contains('BugFix')) { $ReleaseNotes = $ReleaseNotes.AppendLine('Fixed Bugs').AppendLine(($Object1.GetEnumerator().Where({ $_.Name -match '^BugFix\d*$' }).Value | ConvertTo-UnorderedList)).AppendLine() }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes.ToString() | Format-Text
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
