$Object1 = Invoke-WebRequest -Uri 'https://www.thorlabs.com/api/software_pages/check_updates?ItemID=MCM301' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.ItemID.SoftwarePkg.VersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.ItemID.SoftwarePkg.DownloadLink.Replace('\', '/').Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ItemID.SoftwarePkg.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'

      # LicenseUrl (en-US)
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'en-US'
      #   Key    = 'LicenseUrl'
      #   Value  = "https://www.thorlabs.com/Software/THO/MCM301/software/v$($this.CurrentState.Version)/License.zip"
      # }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @(
        [ordered]@{
          RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\')
        }
      )
      $ZipFile.Dispose()
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $ReleaseNotesUrl = $Object1.ItemID.SoftwarePkg.ChangeLog.Replace('\', '/').Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String.Contains("Release V$($this.CurrentState.Version)")) {
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch 'Release V\d+(\.\d+)+ ') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
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
