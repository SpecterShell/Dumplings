$Object1 = @"
<xml>
$((Invoke-WebRequest -Uri 'http://www.jetScreenshot.com/getnews.php' -Method Post -Body @{ UserID = '' } | Read-ResponseContent -Encoding 'windows-1252').Replace('<br>', "`n"))
</xml>
"@ | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.xml.LASTVERSION

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://jetscreenshot.com/jetScreenshot-setup.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.xml.NEWFEATURES | Format-Text
      }
    } catch {
      $this.Log($_, 'Warning')
      $_ | Out-Host
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
