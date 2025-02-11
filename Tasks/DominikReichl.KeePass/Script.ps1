$ProjectName = 'keepass'
$RootPath = '/KeePass 2.x'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))/[\d\.]+/KeePass-.+\.(msi|exe)$" })

# Version
$this.CurrentState.Version = [regex]::Match($Assets[0].title.'#cdata-section', "^$([regex]::Escape($RootPath))/([\d\.]+)/").Groups[1].Value

# Installer
$this.CurrentState.Installer += $InstallerMsi = [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.msi') }, 'First')[0].link | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.exe') }, 'First')[0].link | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.msi') }, 'First')[0].pubDate,
        'ddd, dd MMM yyyy HH:mm:ss "UT"',
        (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFileMsi = Get-TempFile -Uri $InstallerMsi.InstallerUrl -UserAgent $WinGetUserAgent

    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFileMsi | Read-ProductVersionFromMsi
    # InstallerSha256
    $InstallerMsi['InstallerSha256'] = (Get-FileHash -Path $InstallerFileMsi -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries
    $InstallerMsi['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $InstallerMsi['ProductCode'] = $InstallerFileMsi | Read-ProductCodeFromMsi
        UpgradeCode = $InstallerFileMsi | Read-UpgradeCodeFromMsi
      }
    )

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://keepass.info/news/news_all.html'
      }

      $Object2 = (Invoke-WebRequest -Uri 'https://keepass.info/news/news_all.html').Links.Where({ try { $_.href.Contains($this.CurrentState.Version) } catch {} }, 'First')

      if ($Object2) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl = 'https://keepass.info/news/' + $Object2[0].href
        }

        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3.SelectNodes('/html/body/table/tr[1]/td[2]/node()[contains(., "Changes from")]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotesUrl and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
