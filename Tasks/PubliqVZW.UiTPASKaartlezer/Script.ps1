$DownloadPage = 'https://files.uitpas.be/uitpas_balie_plugin.html'
$Object1 = Invoke-WebRequest -Uri $DownloadPage

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $DownloadPage $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('kaartlezer') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://files.uitpas.be/uitpas_balie_plugin_update.xml' | Read-ResponseContent | ConvertFrom-Xml
      $Object3 = $Object2.rss.channel.item.Where({ try { $_.title -match "(?<![\d.])v$([regex]::Escape($this.CurrentState.Version))(?![\d.])" } catch {} }, 'First')

      if ($Object3) {
        $Description = $Object3[0].description | ConvertFrom-Html

        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object3[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (nl-BE)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'nl-BE'
          Key    = 'ReleaseNotes'
          Value  = $Description.SelectNodes('//p') | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (nl-BE)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'nl-BE'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object3[0].link
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (nl-BE) for version $($this.CurrentState.Version)", 'Warning')
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
