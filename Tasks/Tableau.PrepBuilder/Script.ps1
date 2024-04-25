$this.Log($DumplingsDefaultUserAgent, 'Warning')

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = Get-RedirectedUrl1st -Uri 'https://www.tableau.com/support/releases/prep/latest' -Headers @{ Accept = '*/*'; 'User-Agent' = $DumplingsDefaultUserAgent }
}
# ReleaseNotesUrl (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotesUrl'
  Value  = $ReleaseNotesUrlCN = Get-RedirectedUrl1st -Uri 'https://www.tableau.com/zh-cn/support/releases/prep/latest' -Headers @{ Accept = '*/*'; 'User-Agent' = $DumplingsDefaultUserAgent }
}

$Object1 = Invoke-WebRequest -Uri $ReleaseNotesUrl -Headers @{ Accept = '*/*' } | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//script[@data-drupal-selector="drupal-settings-json"]').InnerText.Trim() | ConvertFrom-Json
$Object3 = Invoke-RestMethod -Uri $Object2.tableauReleaseDownloadLinks.url -Headers @{ Accept = '*/*' } | Get-EmbeddedJson -StartsFrom 'jsonCallback(' | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object3.release[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object3.release[0].windows_desktop_installers[0].download_link
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object3.release[0].release_date | Get-Date -Format 'yyyy-MM-dd'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl -Headers @{ Accept = '*/*' }

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromBurn
        UpgradeCode = $InstallerFile | Read-UpgradeCodeFromBurn
      }
    )

    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.SelectNodes('//table[@class="table-list"]/tr/td[2]') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrlCN -Headers @{ Accept = '*/*' } | ConvertFrom-Html

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object4.SelectNodes('//table[@class="table-list"]/tr/td[2]') | Get-TextContent | Format-Text
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
