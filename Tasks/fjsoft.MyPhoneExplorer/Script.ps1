$Object1 = (Invoke-WebRequest -Uri 'https://www.fjsoft.at/myphoneexplorer/version.php').Content

# Version
$this.CurrentState.Version = $Object1.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.fjsoft.at/files/MyPhoneExplorer_Setup_$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.fjsoft.at/en/Versions/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//li[contains(@class, 'accordion-item') and contains(./a[@class='accordion-title']/h2/table/tr/td[1], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./a[@class="accordion-title"]/h2/table/tr/td[2]').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//div[contains(@class, "accordion-content")]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.fjsoft.at/de/Versionen/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object3.SelectSingleNode("//li[contains(@class, 'accordion-item') and contains(./a[@class='accordion-title']/h2/table/tr/td[1], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [datetime]::ParseExact(
          [regex]::Match(
            $ReleaseNotesNode.SelectSingleNode('./a[@class="accordion-title"]/h2/table/tr/td[2]').InnerText,
            '(\d{1,2}\.\d{1,2}\.\d{4})'
          ).Groups[1].Value,
          'dd.MM.yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (de-DE)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'de-DE'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//div[contains(@class, "accordion-content")]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (de-DE) for version $($this.CurrentState.Version)", 'Warning')
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
