$Object1 = Invoke-RestMethod -Uri 'https://api.iclicker.com/v1/clients/bcf4b6b4-a15f-4359-8585-13fffdc75c64/check-for-update' -Method Post -Body (
  @{
    'operatingSystem' = 'WINDOWS'
    'updateCheckType' = 'LAUNCH'
    'userVersion'     = $this.Status.Contains('New') ? '7.1.0' : $this.LastState.Version
  } | ConvertTo-Json -Compress
) -ContentType 'application/json; charset=UTF-8'

# Version
$this.CurrentState.Version = $Object1.details.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object1.details.downloadUrls.WINDOWS "iClicker Cloud Installer $($this.CurrentState.Version).msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.details.releaseNotesUrl
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//p[contains(./b, 'Cloud $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'p' -and $Node.SelectSingleNode('./b')); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
