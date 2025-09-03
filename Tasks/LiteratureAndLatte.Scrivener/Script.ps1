$Object1 = Invoke-WebRequest -Uri 'https://www.literatureandlatte.com/updates/win-scrivener/updates-v3.xml' | Read-ResponseContent | ConvertFrom-xml

# Version
$this.CurrentState.Version = $Object1.installerInformation.release[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.literatureandlatte.com/downloads/win-legacy/Scrivener-$($this.CurrentState.Version.Replace('.', ''))-installer.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = $Object1.installerInformation.release[0].delivery.changelog | ConvertTo-Https
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('//*[@class="date"]').InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('//header/following-sibling::node()') | Get-TextContent | Format-Text
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
