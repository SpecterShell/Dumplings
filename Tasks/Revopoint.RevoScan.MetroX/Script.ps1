$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.revopoint3d.com/pages/support-download' | Join-String -Separator "`n" | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//*[@class="SSIC__content" and contains(., "Revo Scan 5 MetroX")]//div[@class="SSIC__supported-os-card" and @data-os="os-win"]')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('.//a[contains(@href, ".exe")]').Attributes['href'].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayVersion = $InstallerFile | Read-ProductVersionFromExe
      }
    )

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      if ($Global:DumplingsStorage.Contains('RevoScanMetroX') -and $Global:DumplingsStorage.RevoScanMetroX.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.RevoScanMetroX[$this.CurrentState.Version].ReleaseNotes
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.RevoScanMetroX[$this.CurrentState.Version].ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
