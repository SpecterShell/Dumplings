$Object1 = Invoke-WebRequest -Uri 'https://www.artweaver.de/en/download' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[@class="mt-5" and contains(., "Artweaver Free")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.InnerText, 'Version: (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.artweaver.de/direct/Artweaver.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Object2.InnerText, '(\d{1,2}\.\d{1,2}\.20\d{2})').Groups[1].Value,
        'dd.MM.yyyy',
        $null
      ).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://www.artweaver.de/en/changelog'
      }

      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl
      $ReleaseNotesLink = $Object3.Links.Where({ try { $_.outerHTML -match "Artweaver $($this.CurrentState.Version)" } catch {} }, 'First')
      if ($ReleaseNotesLink) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl = Join-Uri $ReleaseNotesUrl $ReleaseNotesLink[0].href
        }

        $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object4.SelectNodes('//*[@class="section-title"]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[2]) {
      $this.Log("The WinGet package needs to be updated to the version $($this.CurrentState.Version.Split('.')[0])", 'Error')
    } else {
      $this.Submit()
    }
  }
}
