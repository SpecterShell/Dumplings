$Object1 = Invoke-WebRequest -Uri 'https://www.hin.ch/de/info/download.cfm'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://support.hin.ch/de/hin-client/release-notes-hin-client/' | ConvertFrom-Html

      if ($Object2.SelectSingleNode("//h1[@class='entry-title' and contains(text(), '$($this.CurrentState.Version)')]")) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($Object2.SelectSingleNode('//div[@class="entry-content"]').InnerText, '(\d{1,2}\.\d{1,2}\.20\d{2})').Groups[1].Value,
          'dd.MM.yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # Remove "Release Notes: Archiv" link
        $Object2.SelectNodes('//a[contains(., "Release Notes: Archiv")]').ForEach({ $_.Remove() })
        # ReleaseNotes (de-CH)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'de-CH'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectSingleNode('//div[@class="entry-content"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://support.hin.ch/fr/hin-client/release-notes-hin-client/' | ConvertFrom-Html

      if ($Object3.SelectSingleNode("//h1[@class='entry-title' and contains(text(), '$($this.CurrentState.Version)')]")) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($Object3.SelectSingleNode('//div[@class="entry-content"]').InnerText, '(\d{1,2}\.\d{1,2}\.20\d{2})').Groups[1].Value,
          'dd.MM.yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # Remove "Archive: Notes de release du client HIN" link
        $Object3.SelectNodes('//a[contains(., "Archive: Notes de release du client HIN")]').ForEach({ $_.Remove() })
        # ReleaseNotes (fr-CH)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'fr-CH'
          Key    = 'ReleaseNotes'
          Value  = $Object3.SelectSingleNode('//div[@class="entry-content"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-WebRequest -Uri 'https://support.hin.ch/it/hin-client/note-di-rilascio-hin-client/' | ConvertFrom-Html

      if ($Object4.SelectSingleNode("//h1[@class='entry-title' and contains(text(), '$($this.CurrentState.Version)')]")) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($Object4.SelectSingleNode('//div[@class="entry-content"]').InnerText, '(\d{1,2}\.\d{1,2}\.20\d{2})').Groups[1].Value,
          'dd.MM.yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # Remove "Archivio: Note di rilascio HIN Client" link
        $Object4.SelectNodes('//a[contains(., "Archivio: Note di rilascio HIN Client")]').ForEach({ $_.Remove() })
        # ReleaseNotes (it-CH)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'it-CH'
          Key    = 'ReleaseNotes'
          Value  = $Object4.SelectSingleNode('//div[@class="entry-content"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
