$Object1 = Invoke-RestMethod -Uri 'https://downloads.cm.thycotic.com/LatestVersion.xml'

# Version
$this.CurrentState.Version = $Object1.item.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.item.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # try {
    #   # ReleaseNotes (en-US)
    #   $this.CurrentState.Locale += [ordered]@{
    #     Locale = 'en-US'
    #     Key    = 'ReleaseNotes'
    #     Value  = $Object1.item.changelog | Format-Text
    #   }
    # } catch {
    #   $_ | Out-Host
    #   $this.Log($_, 'Warning')
    # }

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
