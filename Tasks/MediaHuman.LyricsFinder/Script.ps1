$Object1 = @"
<VersionInfos>
$((Invoke-WebRequest -Uri 'https://www.mediahuman.com/files/LyricsFinder.xml').Content)
</VersionInfos>
"@ | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.VersionInfos.VersionInfo[0].current

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.VersionInfos.VersionInfo[0].url.win[0].'#text'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.VersionInfos.VersionInfo[0].date, 'dd/MM/yyyy', $null).ToString('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.VersionInfos.VersionInfo[0].changes | Format-Text
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
