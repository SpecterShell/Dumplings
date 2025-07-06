$Prefix = 'https://apps.netdocuments.com/apps/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}appVersions.xml"
$Object2 = $Object1.GetElementsByTagName('InstallerPackageInfo').Where({ $_.id -eq 'ndOffice' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object2.url "ndOfficeSetup-$($this.CurrentState.Version.Split('.')[0..2] -join '.').zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $ReleaseNotesUrl = "https://support.netdocuments.com/s/article/ndOffice-$($this.CurrentState.Version.Split('.')[0..2] -join '-' -replace '-0$')-Release-Notes"
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl -Method Head -SkipHttpErrorCheck
      if ($Object3.StatusCode -eq 200) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # TODO: Parse ReleaseNotes (en-US)
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
