$Object1 = Invoke-RestMethod -Uri 'https://ddawebsite-prod.azurewebsites.net/releases/Update.xml'

# Version
$this.CurrentState.Version = $Object1.item.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://ddawebsite-prod.azurewebsites.net/releases/DEWALT_DESIGN_ASSIST.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1.item.changelog_English | ConvertTo-Https
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
