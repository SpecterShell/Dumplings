$Object1 = [regex]::Match(
  (Invoke-WebRequest -Uri 'https://www.mediahuman.com/files/VideoConverter2.xml').Content,
  '(?s)(<VersionInfo>.+?</VersionInfo>)'
).Groups[1].Value | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.VersionInfo.current

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.VersionInfo.url.win.'#text' | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
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
