$ProjectName = 'keepass'
$ProjectPath = '/KeePass 2.x'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${ProjectPath}"

# Version
$this.CurrentState.Version = [regex]::Match(
  ($Object1.title.'#cdata-section' -match "^$([regex]::Escape($ProjectPath))/[\d\.]+/KeePass-.+\.(msi|exe)$")[0],
  "^$([regex]::Escape($ProjectPath))/([\d\.]+)/"
).Groups[1].Value

$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($ProjectPath))/$([regex]::Escape($this.CurrentState.Version))/KeePass-.+\.(msi|exe)$" })

# Installer
$this.CurrentState.Installer += $InstallerMsi = [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.msi') }, 'First')[0].link | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.exe') }, 'First')[0].link | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact(
  $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.msi') }, 'First')[0].pubDate,
  'ddd, dd MMM yyyy HH:mm:ss "UT"',
  (Get-Culture -Name 'en-US')
) | ConvertTo-UtcDateTime -Id 'UTC'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFileMsi = Get-TempFile -Uri $InstallerMsi.InstallerUrl -UserAgent 'Microsoft-Delivery-Optimization/10.0'

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
      $Object2 = (Invoke-WebRequest -Uri 'https://keepass.info/news/news_all.html').Links.href.Where({ $_.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl = 'https://keepass.info/news/' + $Object2[0]
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://keepass.info/news/news_all.html'
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://keepass.info/news/news_all.html'
      }
    }

    try {
      if ($Object2) {
        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3.SelectNodes('/html/body/table/tr[1]/td[2]/node()[contains(., "Changes from")]/following-sibling::node()') | Get-TextContent | Format-Text
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
