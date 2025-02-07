$Object1 = Invoke-RestMethod -Uri 'https://updates.mirillis.com/liveupdate/liveupdate_action.xml'

# Version
$this.CurrentState.Version = $Object1.splash.update.version1

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://downloads.mirillis.com/files/action_$($this.CurrentState.RealVersion.Replace('.', '_'))_setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://updates.mirillis.com/liveupdate/news/0804/news.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//table[@class='news_table']/tr[contains(.//div[@class='itemHeader'], 'Action! $($this.CurrentState.RealVersion)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesNode.SelectSingleNode('./td[1]//div[@class="itemDate2"]').InnerText, '(\d{1,2}/\d{1,2}/\d{4})').Groups[1].Value,
          'MM/dd/yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('.//div[@class="itemText"]') | Get-TextContent | Format-Text
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
