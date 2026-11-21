# Version and Installer
# Not every release directory carries every product, so take the newest version that publishes both Windows packages.
foreach ($Candidate in $Global:DumplingsStorage.BicomSystemsVersions) {
  $UrlEXE = "$($Global:DumplingsStorage.BicomSystemsDownloadRoot)${Candidate}/glocom/gloCOM-${Candidate}.exe"
  $UrlMSIX = "$($Global:DumplingsStorage.BicomSystemsDownloadRoot)${Candidate}/glocom/gloCOM-${Candidate}.msix"
  if (((Invoke-WebRequest -Uri $UrlEXE -Method Head -MaximumRetryCount 0 -SkipHttpErrorCheck).StatusCode -eq 200) -and
    ((Invoke-WebRequest -Uri $UrlMSIX -Method Head -MaximumRetryCount 0 -SkipHttpErrorCheck).StatusCode -eq 200)) {
    # Version
    $this.CurrentState.Version = $Candidate
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerType          = 'exe'
      InstallerUrl           = $UrlEXE
      AppsAndFeaturesEntries = @(
        [ordered]@{
          DisplayVersion = $Candidate
        }
      )
    }
    $this.CurrentState.Installer += [ordered]@{
      InstallerType = 'msix'
      InstallerUrl  = $UrlMSIX
    }
    break
  }
}
if (-not $this.CurrentState.Contains('Version')) {
  throw 'No gloCOM installer pair was found in the Bicom Systems download index.'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesUrl = "$($Global:DumplingsStorage.BicomSystemsChangelogRoot)Changelog_gloCOM_${Candidate}.pdf"
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

    $this.InstallerFiles[$UrlMSIX] = $InstallerFile = Get-TempFile -Uri $UrlMSIX
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMSIX

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
