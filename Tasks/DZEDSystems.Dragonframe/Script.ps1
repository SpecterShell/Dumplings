$Object1 = Invoke-RestMethod -Uri 'https://www.dragonframe.com/update.php' -Method Post -Form @{
  product    = 'WIN-DRAGON'
  os         = 'Windows 10.0.22000'
  activation = ''
} | ConvertFrom-StringData

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.download_url | ConvertTo-Https
  ProductCode  = "Dragonframe $($this.CurrentState.Version.Split('.')[0]) $($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1.release_notes_url | ConvertTo-Https
      }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html | Get-TextContent | Format-Text
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
