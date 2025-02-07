$UserAgent = 'libcurl-client'

$Object1 = Invoke-WebRequest -Uri 'https://www.tableau.com/support/releases/prep/latest' -UserAgent $UserAgent
# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
}

$Object2 = $Object1 | ConvertFrom-Html
$Object3 = $Object2.SelectSingleNode('//script[@data-drupal-selector="drupal-settings-json"]').InnerText.Trim() | ConvertFrom-Json
$Object4 = Invoke-RestMethod -Uri $Object3.tableauReleaseDownloadLinks.url -UserAgent $UserAgent | Get-EmbeddedJson -StartsFrom 'jsonCallback(' | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object4.release[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object4.release[0].windows_desktop_installers[0].download_link
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object4.release[0].release_date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('//table[@class="table-list"]/tr/td[2]') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl -UserAgent $UserAgent

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
      $Object5 = Invoke-WebRequest -Uri 'https://www.tableau.com/zh-cn/support/releases/prep/latest' -UserAgent $UserAgent
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object5.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
      }

      $Object6 = $Object5 | ConvertFrom-Html
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object6.SelectNodes('//table[@class="table-list"]/tr/td[2]') | Get-TextContent | Format-Text
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
