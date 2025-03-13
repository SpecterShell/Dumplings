$ProjectName = 'keepass'
$RootPath = '/KeePass 2.x'
$PatternPath = '(\d+(?:\.\d+)+)'
$PatternFilename = 'KeePass-.+\.(msi|exe)'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))/${PatternPath}/${PatternFilename}$" })

# Installer
$Asset = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.msi') }, 'First')[0]
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = $Asset.link | ConvertTo-UnescapedUri
}
$VersionMSI = [regex]::Match($Asset.title.'#cdata-section', "^$([regex]::Escape($RootPath))/${PatternPath}/").Groups[1].Value

$Asset = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.exe') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = $Asset.link | ConvertTo-UnescapedUri
}
$VersionInno = [regex]::Match($Asset.title.'#cdata-section', "^$([regex]::Escape($RootPath))/${PatternPath}/").Groups[1].Value

if ($VersionMSI -ne $VersionInno) {
  $this.Log("MSI version: ${VersionMSI}")
  $this.Log("Inno version: ${VersionInno}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionInno

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Asset.pubDate, 'ddd, dd MMM yyyy HH:mm:ss "UT"', (Get-Culture -Name 'en-US')) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl -UserAgent $WinGetUserAgent
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
