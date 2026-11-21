$Prefix = 'https://download.kde.org/stable/gcompris/qt/windows/'

$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = $InstallerUrlEXE = Join-Uri $Prefix ($Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('win64') } catch {} }).href | Sort-Object -Property { [Version][regex]::Match($_, '(\d+(?:\.\d+)+)').Groups[1].Value } -Bottom 1)
}
$VersionEXE = [regex]::Match($InstallerUrlEXE, '(\d+(?:\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $InstallerUrlMSI = Join-Uri $Prefix ($Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('win64') } catch {} }).href | Sort-Object -Property { [Version][regex]::Match($_, '(\d+(?:\.\d+)+)').Groups[1].Value } -Bottom 1)
}
$VersionMSI = [regex]::Match($InstallerUrlMSI, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionEXE -ne $VersionEXE) {
  $this.Log("EXE version: ${VersionEXE}")
  $this.Log("MSI version: ${VersionMSI}")
  $this.Log('Inconsistent versions detected', 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionEXE

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://gcompris.net/news-en.html'
      }

      $Object2 = (Invoke-RestMethod -Uri 'https://www.gcompris.net/feed-en.xml').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].description | ConvertFrom-Html | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object2[0].link
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://gcompris.net/news-zh_CN.html'
      }

      $Object3 = (Invoke-RestMethod -Uri 'https://www.gcompris.net/feed-zh_CN.xml').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object3) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $Object3[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].description | ConvertFrom-Html | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object3[0].link
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (zh-CN) and ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
