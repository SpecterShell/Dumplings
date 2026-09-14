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
      $Object2 = Invoke-WebRequest -Uri 'https://support.hin.ch/de/thema/hin-client/release-notes.cfm' | ConvertFrom-Html

      if ($ReleaseNotesDETitleNode = $Object2.SelectSingleNode("//article/section[./div[1]/h2[contains(text(), '$($this.CurrentState.Version)')]]")) {
        if (($ReleaseTimeDENode = $ReleaseNotesDETitleNode.SelectSingleNode('.//p[contains(., "Release Datum")]')) -and $ReleaseTimeDENode.InnerText -match '(\d{1,2}\.\d{1,2}\.20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'dd.MM.yyyy', $null).ToString('yyyy-MM-dd')

          # ReleaseNotes (de-CH)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'de-CH'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseTimeDENode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
          }
        } else {
          # ReleaseNotes (de-CH)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'de-CH'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesDETitleNode.SelectSingleNode('./div[last()]') | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (de-CH) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://support.hin.ch/fr/thema/hin-client/notes-de-release.cfm' | ConvertFrom-Html

      if ($ReleaseNotesFRTitleNode = $Object3.SelectSingleNode("//article/section[./div[1]/h2[contains(text(), '$($this.CurrentState.Version)')]]")) {
        if (($ReleaseTimeFRNode = $ReleaseNotesFRTitleNode.SelectSingleNode('.//p[contains(., "Date de release")]')) -and $ReleaseTimeFRNode.InnerText -match '(\d{1,2}\.\d{1,2}\.20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'dd.MM.yyyy', $null).ToString('yyyy-MM-dd')

          # ReleaseNotes (fr-CH)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'fr-CH'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseTimeFRNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
          }
        } else {
          # ReleaseNotes (fr-CH)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'fr-CH'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesFRTitleNode.SelectSingleNode('./div[last()]') | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (fr-CH) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-WebRequest -Uri 'https://support.hin.ch/it/thema/hin-client/note-di-rilascio.cfm' | ConvertFrom-Html

      if ($ReleaseNotesITTitleNode = $Object4.SelectSingleNode("//article/section[./div[1]/h2[contains(text(), '$($this.CurrentState.Version)')]]")) {
        if (($ReleaseTimeITNode = $ReleaseNotesITTitleNode.SelectSingleNode('.//p[contains(., "Data di rilascio")]')) -and $ReleaseTimeITNode.InnerText -match '(\d{1,2}\.\d{1,2}\.20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'dd.MM.yyyy', $null).ToString('yyyy-MM-dd')

          # ReleaseNotes (it-CH)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'it-CH'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseTimeITNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
          }
        } else {
          # ReleaseNotes (it-CH)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'it-CH'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesITTitleNode.SelectSingleNode('./div[last()]') | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (it-CH) for version $($this.CurrentState.Version)", 'Warning')
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
