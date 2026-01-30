$LastVersionParts = $this.Status.Contains('New') ? @(4, 2, 3) : $this.LastState.Version.Split('.')
$Object1 = Invoke-RestMethod -Uri 'https://update.spark-space.com/cgi-bin/updateinfo.cgi' -Body @{
  program    = 'EssayWriter'
  os         = 'win32'
  serialno   = '0'
  major      = $LastVersionParts[0]
  minor      = $LastVersionParts[1]
  patchlevel = $LastVersionParts[2]
}

if ($Object1.Contains('noupdate')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$Object2 = $Object1 | ConvertFrom-StringData

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.downloadlink
}

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'EssayWriter.msi'
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://support.biosilico.com/portal/kb/ideamapper/release-notes'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://support.biosilico.com/portal/api/kbArticles?portalId=edbsn50c65f988ca4437840400b8dcfac069b5190e5a2a1bb325e871ce212bb92e126&categoryId=125023000000188440&includeChildCategoryArticles=false&locale=en'
      if ($ReleaseNotesUrlObject = $Object2.data.Where({ $_.title.Contains($this.CurrentState.RealVersion) }, 'First')) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrlObject[0].webUrl.Replace('/en/', '/')
        }

        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesUrlObject[0].modifiedTime.ToUniversalTime()

        $Object3 = Invoke-RestMethod -Uri "https://support.biosilico.com/portal/api/kbArticles/articleByPermalink?portalId=edbsn50c65f988ca4437840400b8dcfac069b5190e5a2a1bb325e871ce212bb92e126&permalink=$($ReleaseNotesUrlObject[0].permalink)"
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3.answer | ConvertFrom-Html | Get-TextContent | Format-Text
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
