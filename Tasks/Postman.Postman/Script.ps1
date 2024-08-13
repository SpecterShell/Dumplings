$Object1 = Invoke-WebRequest -Uri "https://dl.pstmn.io/update/WIN64/$($this.LastState.Version ?? '11.8.0')/stable"

if ($Object1.code -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($Object1.content, '(\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://dl.pstmn.io/download/version/${Version}/win64"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://dl.pstmn.io/api/version/notes'

      $ReleaseNotesObject = $Object2.notes.Where({ $_.version -eq $Version }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesObject.content -replace '^## .+' | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.postman.com/release-notes/postman-app/'
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
