$Object1 = [regex]::Match(
  (Invoke-WebRequest -Uri 'https://www.mediahuman.com/files/YouTubeDownloader.xml').Content,
  '(?s)(<VersionInfo>.+?</VersionInfo>)'
).Groups[1].Value | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.VersionInfo.current

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.VersionInfo.url.win[0].'#text' | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.VersionInfo.url.win64[0].'#text' | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.VersionInfo.date, 'dd/MM/yyyy', $null).ToString('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.VersionInfo.changes | Format-Text
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
