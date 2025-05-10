$Object1 = Invoke-WebRequest -Uri 'https://s3browser.com/download.aspx'

# Installer
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}
$VersionEXE = [regex]::Match($InstallerEXE.InstallerUrl, '(\d+(-\d+)+)').Groups[1].Value.Replace('-', '.')

$this.CurrentState.Installer += $InstallerMSI = [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
}
$VersionMSI = [regex]::Match($InstallerMSI.InstallerUrl, '(\d+(-\d+)+)').Groups[1].Value.Replace('-', '.')

if ($VersionEXE -ne $VersionMSI) {
  $this.Log("EXE version: ${VersionEXE}")
  $this.Log("MSI version: ${VersionMSI}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionEXE

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://s3browser.com/rss.xml').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].pubDate | Get-Date -AsUTC

        $ReleaseNotesObject = $Object2[0].description | ConvertFrom-Html
        # Remove download link
        $ReleaseNotesObject.SelectSingleNode('.//a[contains(., "Download S3 Browser")]').Remove()
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
