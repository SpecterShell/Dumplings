# Not every release directory carries every product, so take the newest version that publishes this one.
foreach ($Candidate in $Global:DumplingsStorage.BicomSystemsVersions) {
  $Url = "$($Global:DumplingsStorage.BicomSystemsDownloadRoot)${Candidate}/communicator/Communicator-${Candidate}.exe"
  if ((Invoke-WebRequest -Uri $Url -Method Head -MaximumRetryCount 0 -SkipHttpErrorCheck).StatusCode -eq 200) {
    # Version
    $this.CurrentState.Version = $Candidate
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'exe'
      InstallerUrl  = $Url
    }
    break
  }
}
if (-not $this.CurrentState.Contains('Version')) {
  throw 'No Communicator installer was found in the Bicom Systems download index.'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesUrl = "$($Global:DumplingsStorage.BicomSystemsChangelogRoot)Changelog_Communicator_${Candidate}.pdf"
      if ((Invoke-WebRequest -Uri $ReleaseNotesUrl -Method Head -MaximumRetryCount 0 -SkipHttpErrorCheck).StatusCode -ne 200) {
        $ReleaseNotesUrl = $null
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
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
