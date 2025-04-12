$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://kodi.tv/download/windows/' | Join-String -Separator "`n"
$Object2 = Get-EmbeddedLinks -Content $Object1

# Version
$this.CurrentState.Version = [regex]::Match($Object1, 'Kodi v(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.Where({ try { $_.href.Contains('x86') } catch {} }, 'First')[0].href | Split-Uri -LeftPart Path
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.Where({ try { $_.href.Contains('x64') } catch {} }, 'First')[0].href | Split-Uri -LeftPart Path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://kodi.tv/blog/'
      }

      $Object3 = (Invoke-RestMethod -Uri 'https://kodi.tv/rss.xml').Where({ $_.title.'#cdata-section'.Contains("Kodi $($this.CurrentState.Version)") }, 'First')
      if ($Object3) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object3[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].encoded | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object3[0].link
        }
      } else {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
