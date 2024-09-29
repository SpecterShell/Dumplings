$Object1 = Invoke-RestMethod -Uri 'https://www.screenpresso.com/binaries/version4.xml'

# Version
$this.CurrentState.Version = $Object1.checkforupdate.latestversion.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = $Object1.checkforupdate.latestversion.downloadurl
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = $Object1.checkforupdate.latestversion.downloadurl | Split-Uri -Parent | Join-Uri -ChildUri 'ScreenpressoSetup.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.checkforupdate.latestversion.builddate | Get-Date -Format 'yyyy-MM-dd'

    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = 'https://www.screenpresso.com/releases/'
    }
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'de-DE'
      Key    = 'ReleaseNotesUrl'
      Value  = 'https://www.screenpresso.com/de/softwareveroffentlichung/'
    }
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'fr-FR'
      Key    = 'ReleaseNotesUrl'
      Value  = 'https://www.screenpresso.com/fr/versions/'
    }

    try {
      $Object2 = Invoke-WebRequest -Uri $Object1.checkforupdate.latestversion.releasesummary | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('//div[contains(@class, "container")]') | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.checkforupdate.latestversion.releaseurl
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'de-DE'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.checkforupdate.latestversion.releaseurl.Replace('releases', 'de/softwareveroffentlichung')
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'fr-FR'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.checkforupdate.latestversion.releaseurl.Replace('releases', 'fr/versions')
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
