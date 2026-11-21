$Object1 = Invoke-RestMethod -Uri 'https://jabraxpressonlineprdstor.blob.core.windows.net/jdo/jdo.json'

# Version
$this.CurrentState.Version = $Object1.WindowsVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.WindowsDownload
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1.WindowsReleaseNotes
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      if ($Object3.SelectSingleNode('//*[@data-testid="release-version"]').InnerText -eq $this.CurrentState.Version) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($Object3.SelectSingleNode('//*[@data-testid="formatted-date"]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove "share" button
        $Object3.SelectNodes('//button[contains(., "Share")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3.SelectSingleNode('//*[@data-testid="release-content"]') | Get-TextContent | Format-Text
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
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
