$Object1 = Invoke-WebRequest -Uri 'https://www.isobuster.com/isobuster/onlinecheck.php' -UserAgent 'Mozilla/5.0 (compatible; IsoBuster)'
$Object2 = ([regex]::Match($Object1.Content, '(?s)<!--(.+?)-->').Groups[1].Value | ConvertFrom-Ini).'IsoBuster Online Query Response Data'

# Version
$this.CurrentState.Version = $Object2.BUILD

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://www.isobuster.com/downloads/isobuster/isobuster_install.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://www.isobuster.com/downloads/isobuster/isobuster_install_64bit.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = Get-Date -Year $Object2.BUILD_DATE_YEAR -Month $Object2.BUILD_DATE_MONTH -Day $Object2.BUILD_DATE_DAY -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.isobuster.com/news/'
      }

      $Object3 = (Invoke-RestMethod -Uri 'https://www.isobuster.com/feeds/news.xml').Where({ $_.title.Contains($this.CurrentState.RealVersion) }, 'First')

      if ($Object3) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $Object3[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].description | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object3[0].link
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
      }
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
