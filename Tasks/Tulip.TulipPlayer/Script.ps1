$Prefix = 'https://download.tulip.co/releases/prod/win/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}RELEASES" | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { [RawVersion]$_.Version } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = Join-Uri $Prefix 'Tulip Player Setup.exe'
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri $Prefix 'Tulip Player Setup.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # ProductCode
    $Installer['ProductCode'] = "$($InstallerFile | Read-ProductCodeFromMsi).msq"

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://support.tulip.co/docs/tulip-player-releases'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://support.tulip.co/api/document/get-article-data?is-category=true&articleId=73ae0d94-f47d-457a-b59b-85f17ac1a291&x-versiontype=Knowledgebase'
      if ($ReleaseNotesUrlObject = $Object2.result.articleData.articleIndex.children.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = "https://support.tulip.co/docs/$($ReleaseNotesUrlObject[0].slug)"
        }

        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesUrlObject[0].lastPublishedDate.ToUniversalTime()

        $Object3 = Invoke-RestMethod -Uri "https://support.tulip.co/api/document/get-article-data?articleId=$($ReleaseNotesUrlObject[0].id)&x-versiontype=Knowledgebase"

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3.result.articleData.articleContentForSsr | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
