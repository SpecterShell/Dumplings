$Prefix = 'https://resources.robware.net/resources/prod/'
$Object1 = Invoke-WebRequest -Uri "${Prefix}manifest.json" | Read-ResponseContent | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Name
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.PublishDate.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = (Invoke-WebRequest -Uri 'https://resources.robware.net/resources/prod/versionInfo.json' | ConvertFrom-Json -AsHashtable).Where({ $_.version -eq $this.CurrentState.Version }, 'First')
      if ($Object2) {
        # ReleaseNotes (en-US)
        $ReleaseNotes = [System.Text.StringBuilder]::new()
        if ($Object2[0].Contains('FIXED')) {
          $ReleaseNotes = $ReleaseNotes.AppendLine('FIXED:')
          $ReleaseNotes = $ReleaseNotes.AppendLine(($Object2[0].FIXED | ConvertTo-UnorderedList))
        }
        if ($Object2[0].Contains('ADDED')) {
          $ReleaseNotes = $ReleaseNotes.AppendLine('ADDED:')
          $ReleaseNotes = $ReleaseNotes.AppendLine(($Object2[0].ADDED | ConvertTo-UnorderedList))
        }
        if ($Object2[0].Contains('UPDATED')) {
          $ReleaseNotes = $ReleaseNotes.AppendLine('UPDATED:')
          $ReleaseNotes = $ReleaseNotes.AppendLine(($Object2[0].UPDATED | ConvertTo-UnorderedList))
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes.ToString() | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
