$Object1 = Invoke-WebRequest -Uri 'https://www.thorlabs.com/api/software_pages/check_updates?ItemID=CCT' | Read-ResponseContent | ConvertFrom-Xml

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.ItemID.SoftwarePkg.DownloadLink.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}

# Version
$this.CurrentState.Version = [regex]::Matches($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[-1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $ReleaseNotesUrl = $Object1.ItemID.SoftwarePkg.ChangeLog.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String.Contains("v$($this.CurrentState.Version.Split('.')[0..1] -join '.')")) {
          $null = $Object2.ReadLine() # Skip the next line
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch 'v\d+(\.\d+)+') {
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
